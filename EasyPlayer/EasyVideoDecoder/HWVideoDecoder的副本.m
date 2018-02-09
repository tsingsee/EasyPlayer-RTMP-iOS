//
//  CVPixelVideoDecoder.m
//  iMCU2
//
//  Created by admin on 15/2/14.
//
//

#import "HWVideoDecoder.h"

@interface HWVideoDecoder() {
    CMVideoFormatDescriptionRef videoFormatDescr;
    VTDecompressionSessionRef decompressSession;
    
    uint8_t *spsData;
    uint8_t *ppsData;
    
    unsigned char *pInnerData;
    unsigned int innerLen;
}

@end

@implementation HWVideoDecoder

#pragma mark - VideoToolBox Decompress Frame CallBack

// 2、回调函数可以完成CGBitmap图像转换成UIImage图像的处理，将图像通过队列发送到Control来进行显示处理
void didDecompress(void *decompressionOutputRefCon,
                   void *sourceFrameRefCon,
                   OSStatus status,
                   VTDecodeInfoFlags infoFlags,
                   CVImageBufferRef imageBuffer,
                   CMTime presentationTimeStamp,
                   CMTime presentationDuration) {
    if (status != noErr || !imageBuffer) {
        // error -8969 codecBadDataErr kVTVideoDecoderBadDataErr
        // -12909 The operation couldn’t be completed. (OSStatus error -12909.)
        NSLog(@"Error decompresssing frame at time: %.3f error: %d infoFlags: %u",
              (float)presentationTimeStamp.value / presentationTimeStamp.timescale,
              (int)status,
              (unsigned int)infoFlags);
        return;
    }

    //NSLog(@"Got frame data.\n");
    //NSLog(@"Success decompresssing frame at time: %.3f error: %d infoFlags: %u", (float)presentationTimeStamp.value/presentationTimeStamp.timescale, (int)status, (unsigned int)infoFlags);
    
    if (status == noErr) {
        if (imageBuffer != NULL) {
            __weak __block HWVideoDecoder *weakSelf = (__bridge HWVideoDecoder *)decompressionOutputRefCon;
#if 1
            CVPixelBufferLockBaseAddress(imageBuffer, 0);
            
            void *base;
            size_t width, height, bytesPerRow;
            base = CVPixelBufferGetBaseAddress(imageBuffer);
            width = CVPixelBufferGetWidth(imageBuffer);
            height = CVPixelBufferGetHeight(imageBuffer);
            bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
//            size_t dataSize = CVPixelBufferGetDataSize(imageBuffer);
            
            @autoreleasepool {
                KxVideoFrameRGB *frame = [[KxVideoFrameRGB alloc] init];
                frame.width = width;
                frame.height = height;
                frame.linesize = bytesPerRow;
                frame.hasAlpha = YES;
                frame.rgb = [NSData dataWithBytes:base length:bytesPerRow * height];
                
//                frame.position = video->timeStamp;
                frame.duration = 0.04;
                [weakSelf.hwDelegate getDecodePictureData:frame];
            }
            
            CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
#else
            [weakSelf.hwDelegate getDecodePixelData:imageBuffer];
#endif
        }
    }
}

#pragma mark - init

- (id)initWithDelegate:(id<HWVideoDecoderDelegate>)aDelegate {
    if (self = [super init]) {
        self.hwDelegate = aDelegate;
        innerLen = 0;
        pInnerData = NULL;
    }
    
    return self;
}

#pragma mark - 初始化

- (void) initH264DecoderVideoData:(unsigned char *)pData len:(int)len {
    if (videoFormatDescr == NULL) {
        int spsIndex = 0;
        int spsLength = 0;
        
        int ppsIndex = 0;
        int ppsLength = 0;
        
        getXps(pData, 0, len, 7, &spsIndex, &spsLength);
        getXps(pData, 0, len, 8, &ppsIndex, &ppsLength);
        
        if (spsLength == 0 || ppsLength == 0) {
            return;
        }
        
        if (spsData != NULL) {
            free(spsData);
            spsData = NULL;
        }
        
        if (ppsData != NULL) {
            free(ppsData);
            ppsData = NULL;
        }
        
        spsData = (unsigned char *)malloc(spsLength);
        memcpy(spsData, pData + spsIndex, spsLength);
        
        ppsData = (unsigned char *)malloc(ppsLength);
        memcpy(ppsData, pData + ppsIndex, ppsLength);
        
        const uint8_t* const parameterSetPointers[2] = { spsData, ppsData };
        const size_t parameterSetSizes[2] = { (size_t)spsLength, (size_t)ppsLength };
        
        // 构建CMVideoFormatDescriptionRef
        // CMVideoFormatDescriptionCreateFromH264ParameterSets从基础的流数据将SPS和PPS转化为Format Desc
        OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                              2,
                                                                              parameterSetPointers,
                                                                              parameterSetSizes,
                                                                              4,
                                                                              &videoFormatDescr);
        
        NSLog(@"Found all data for CMVideoFormatDescription. Creation: %@.", (status == noErr) ? @"successfully." : @"failed.");
        if (status != noErr) {
            return;
        }
        
        VTDecompressionOutputCallbackRecord callback;
        callback.decompressionOutputCallback = didDecompress;
        callback.decompressionOutputRefCon = (__bridge void *)self;
        NSDictionary *destinationImageBufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                          [NSNumber numberWithBool:YES], (id)kCVPixelBufferOpenGLESCompatibilityKey,
                                                          [NSNumber numberWithInt:kCVPixelFormatType_32BGRA],(id)kCVPixelBufferPixelFormatTypeKey,
                                                          nil ];
        
        // 1、初始化VTDecompressionSession，设置解码器的相关信息
        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                              videoFormatDescr,
                                              NULL,
                                              (__bridge CFDictionaryRef)destinationImageBufferAttributes,
                                              &callback,
                                              &decompressSession);
        
        NSLog(@"Creating Video Decompression Session: %@.", (status == noErr) ? @"successfully." : @"failed.");
        
        VTSessionSetProperty(decompressSession,
                             kVTDecompressionPropertyKey_ThreadCount,
                             (__bridge CFTypeRef)[NSNumber numberWithInt:1]);
        // 设置实时解码输出（避免延迟）
        VTSessionSetProperty(decompressSession,
                             kVTDecompressionPropertyKey_RealTime,
                             kCFBooleanTrue);
    }
}

int getXps(unsigned char *data, int offset, int length, int type, int *outPos, int *xpsLen) {
    int i;
    int pos0;
    int pos1;
    pos0 = -1;
    
    for (i = offset; i < length - 4; i++) {
        if ((0 == data[i]) && (0 == data[i + 1]) && (1 == data[i + 2]) && (type == (0x0F & data[i + 3]))) {
            pos0 = i;
            break;
        }
    }
    
    if (-1 == pos0) {
        return -1;
    }
    
    pos1 = -1;
    for (i = pos0 + 4; i < length - 4; i++) {
        if ((0 == data[i]) && (0 == data[i + 1]) && (1 == data[i + 2])) {
            pos1 = i;
            
            if (data[i - 1] == 0) {
                // 00 00 00 01
                pos1--;
            }
            break;
        }
    }
    
    if (-1 == pos1) {
        return -2;
    }
    
    *outPos = pos0 + 3;
    *xpsLen = pos1 - pos0 - 3;
    printf("type = %d xpsLen= %d ; outPos = %d pos1 = %d\r\n", type, *xpsLen, *outPos, pos1);
    
    return 0;
}

#pragma mark - 解码

- (int)decodeVideoData:(unsigned char *)pData len:(int)len {
    // NAL_UNIT_TYPpe  1:非idr的片;  5 idr
    if (pData == nil) {
        return -1;
    }
    
    self.type = DEC_264;
    
    [self initH264DecoderVideoData:pData len:len];
    
    int nDiff = 0;
    int nalPackLen = len;
    unsigned char *pTemp = pData;
    for (int i = 0; i < len; i++) {
        if (*(pTemp) == 0 && *(pTemp + 1) == 0) {
            if (*(pTemp + 2) == 1) {
                int nalu_type = ((uint8_t)*(pTemp+3) & 0x1F);
                if (nalu_type == 1 || nalu_type == 5) {
                    nDiff = 3;
                    break;
                }
            } else if (*(pTemp + 2) == 0 && *(pTemp + 3) == 1) {
                int nalu_type = ((uint8_t)*(pTemp+4) & 0x1F);
                
                if (nalu_type == 1 || nalu_type == 5) {
                    nDiff = 4;
                    break;
                }
            }
        }
        
        pTemp++;
        nalPackLen--;
    }
    
    if (nDiff == 0) {
        return -1;
    }
    
    int nalu_type = ((uint8_t)*(pTemp + nDiff) & 0x1F);
    
    if (nalu_type == 1 || nalu_type == 5) {
        if (nDiff == 3) {
            // 只有2个0 前面补位0
            if (innerLen <= nalPackLen) {
                innerLen = nalPackLen + 1;
                pInnerData = (unsigned char *)realloc(pInnerData, innerLen);
            }
            
            memcpy(pInnerData + 1, pTemp, nalPackLen);
            pTemp = pInnerData;
            nalPackLen++;
        }
        
        // CMBlockBuffer：编码后，结果图像的数据结构(视频图像数据就是CMBlockBuffer)
        CMBlockBufferRef videoBlock = NULL;
        OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL,
                                                             pTemp,
                                                             nalPackLen,
                                                             kCFAllocatorNull,
                                                             NULL,
                                                             0,
                                                             nalPackLen,
                                                             0,
                                                             &videoBlock);
        
        int reomveHeaderSize = nalPackLen - 4;
        const uint8_t sourceBytes[] = {(uint8_t)(reomveHeaderSize >> 24), (uint8_t)(reomveHeaderSize >> 16), (uint8_t)(reomveHeaderSize >> 8), (uint8_t)reomveHeaderSize};
        status = CMBlockBufferReplaceDataBytes(sourceBytes, videoBlock, 0, 4);
        
        CMSampleBufferRef sbRef = NULL;
        const size_t sampleSizeArray[] = {(size_t)len};
        status = CMSampleBufferCreate(kCFAllocatorDefault, videoBlock, true, NULL, NULL, videoFormatDescr, 1, 0, NULL, 1, sampleSizeArray, &sbRef);
        
        VTDecodeFrameFlags flags = 0;
        VTDecodeInfoFlags flagOut = 0;
        
        // 3、解码操作,解码后的图像会交由didDecompress回调函数，来进一步的处理。
        status = VTDecompressionSessionDecodeFrame(decompressSession,
                                                   sbRef,
                                                   flags,
                                                   &sbRef,
                                                   &flagOut);
        if (status == noErr) {
           status = VTDecompressionSessionWaitForAsynchronousFrames(decompressSession);
        }
        
        CFRelease(sbRef);

        sbRef = NULL;
    }
    
    return 0;
}

#pragma mark - 关闭解码器

- (void)closeDecoder {
    NSLog(@"closeDecoder %@", self);
    
    if (spsData != NULL) {
        free(spsData);
        spsData = NULL;
    }
    
    if (ppsData != NULL) {
        free(ppsData);
        ppsData = NULL;
    }
    
    if (decompressSession) {
        VTDecompressionSessionInvalidate(decompressSession);
        CFRelease(decompressSession);
        decompressSession = NULL;
    }

    if (videoFormatDescr) {
        CFRelease(videoFormatDescr);
        videoFormatDescr = NULL;
    }
    
    if (pInnerData != NULL) {
        free(pInnerData);
        pInnerData = NULL;
    }
    
    innerLen = 0;
}

@end
