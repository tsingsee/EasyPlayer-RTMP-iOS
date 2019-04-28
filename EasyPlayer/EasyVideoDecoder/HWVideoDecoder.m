//
//  CVPixelVideoDecoder.m
//  iMCU2
//
//  Created by admin on 15/2/14.
//

#import "HWVideoDecoder.h"

@interface HWVideoDecoder() {
    CMVideoFormatDescriptionRef videoFormatDescr;   // 源数据的描述
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
        NSLog(@"Error decompresssing frame at time: %.3f error: %d infoFlags: %u",
              (float)presentationTimeStamp.value / presentationTimeStamp.timescale,
              (int)status,
              (unsigned int)infoFlags);
        return;
    }
    
    if (status == noErr) {
        if (imageBuffer != NULL) {
            __weak __block HWVideoDecoder *weakSelf = (__bridge HWVideoDecoder *)decompressionOutputRefCon;
#if 1
//            yuv(imageBuffer, weakSelf);
            rgb(imageBuffer, weakSelf);
#else
            [weakSelf.hwDelegate getDecodePixelData:imageBuffer];
#endif
        }
    }
}

// TODO 第一种显示方式：KxVideoFrameYUV
void yuv(CVImageBufferRef imageBuffer, HWVideoDecoder *weakSelf) {
    size_t w, h, linesizey, linesizeuv;
    void* srcy = NULL;
    void* srcuv = NULL;
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    if (CVPixelBufferIsPlanar(imageBuffer)) {
        size_t count = CVPixelBufferGetPlaneCount(imageBuffer);
        printf("CVPixelBufferGetPlaneCount=%zu\n",count);
        
        w = CVPixelBufferGetWidth(imageBuffer);
        h = CVPixelBufferGetHeight(imageBuffer);
        
        linesizey = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
        linesizeuv = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1);
        
        srcy = (unsigned char*) CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
        srcuv = (unsigned char*) CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
        
        @autoreleasepool {
            KxVideoFrameYUV *frame = [[KxVideoFrameYUV alloc] init];
            frame.width = w;
            frame.height = h;
            frame.duration = 0.04;
            
            frame.luma = [NSData dataWithBytes:srcy length:w * h];
            frame.chromaB = [NSData dataWithBytes:srcy length:w * h / 4];
            frame.chromaR = [NSData dataWithBytes:srcy length:w * h / 4];
            
            [weakSelf.hwDelegate getDecodePictureData:frame length:(unsigned int)(frame.luma.length + frame.chromaB.length + frame.chromaR.length)];
        }
    }
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

// 第二种显示方式：KxVideoFrameRGB
void rgb(CVImageBufferRef imageBuffer, HWVideoDecoder *weakSelf) {
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // 获取图像内部数据
    void *base;
    size_t width, height, bytesPerRow;
    base = CVPixelBufferGetBaseAddress(imageBuffer);
    width = CVPixelBufferGetWidth(imageBuffer);
    height = CVPixelBufferGetHeight(imageBuffer);
    bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t dataSize = CVPixelBufferGetDataSize(imageBuffer);
    NSLog(@"%zu", dataSize);
    
    @autoreleasepool {
        KxVideoFrameRGB *frame = [[KxVideoFrameRGB alloc] init];
        frame.width = width;
        frame.height = height;
        frame.linesize = bytesPerRow;
        frame.hasAlpha = YES;
        frame.rgb = [NSData dataWithBytes:base length:bytesPerRow * height];
        frame.duration = 0.04;
        
        [weakSelf.hwDelegate getDecodePictureData:frame length:(unsigned int)frame.rgb.length];
    }
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
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

- (void) initH264DecoderVideoData:(unsigned char *)pData len:(int)len isInit:(BOOL)isInit {
    // 1、提取sps和pps生成format description
    if (videoFormatDescr == NULL || isInit) {
        int spsIndex = 0;
        int spsLength = 0;
        
        int ppsIndex = 0;
        int ppsLength = 0;
        
        getXps(pData, 0, len, 7, &spsIndex, &spsLength);// 7代表sps
        getXps(pData, 0, len, 8, &ppsIndex, &ppsLength);// 8代表pps
        
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
        
        // H.264的SPS和PPS包含了初始化H.264解码器所需要的信息参数，包括编码所用的profile，level，图像的宽和高，deblock滤波器等。
        // 解析过的SPS和PPS
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
        if (status != noErr) {
            return;
        }
        
        VTDecompressionOutputCallbackRecord callback;
        callback.decompressionOutputCallback = didDecompress;
        callback.decompressionOutputRefCon = (__bridge void *)self;
        // destinationImageBufferAttributes
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES], (id)kCVPixelBufferOpenGLESCompatibilityKey,
                                    [NSNumber numberWithInt:kCVPixelFormatType_32BGRA],(id)kCVPixelBufferPixelFormatTypeKey,
                                    nil ];
        
        // 1、创建解码会话,初始化VTDecompressionSession，设置解码器的相关信息
        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                              videoFormatDescr,
                                              NULL,
                                              (__bridge CFDictionaryRef)attributes,
                                              &callback,
                                              &decompressSession);
        
//        VTSessionSetProperty(decompressSession,
//                             kVTDecompressionPropertyKey_ThreadCount,
//                             (__bridge CFTypeRef)[NSNumber numberWithInt:1]);
//
//        // 设置实时解码输出（避免延迟）
//        VTSessionSetProperty(decompressSession,
//                             kVTDecompressionPropertyKey_RealTime,
//                             kCFBooleanTrue);
//
//        // h264 profile, 直播一般使用baseline，可减少由于b帧带来的延时
//        VTSessionSetProperty(decompressSession,
//                             kVTCompressionPropertyKey_ProfileLevel,
//                             kVTProfileLevel_H264_Baseline_AutoLevel);
    }
}

/**
 读取sps pps数据的逻辑(获取sps、pps的起始位置和长度)

 @param data        数据
 @param offset      从0开始
 @param length      数据长度
 @param type        7代表sps,8代表pps(0x67是SPS的NAL头，0x68是PPS的NAL头)
 @param outPos      sps、pps的起始位置
 @param xpsLen      sps、pps的长度
 */
void getXps(unsigned char *data, int offset, int length, int type, int *outPos, int *xpsLen) {
    int i;
    int startCodeIndex = -1;
    
    // 0x00 00 00 01四个字节为StartCode，在两个StartCode之间的内容即为一个完整的NALU。
    // 存储的一般形式为: 00 00 00 01 SPS 00 00 00 01 PPS 00 00 00 01 I帧
    for (i = offset; i < length - 4; i++) {
        if ((0 == data[i]) && (0 == data[i + 1]) && (1 == data[i + 2]) && (type == (0x0F & data[i + 3]))) {
            startCodeIndex = i;
            break;
        }
    }
    
    if (-1 == startCodeIndex) {
        return;
    }
    
    int pos1 = -1;
    for (i = startCodeIndex + 4; i < length - 4; i++) {
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
        return;
    }
    
    *outPos = startCodeIndex + 3;
    *xpsLen = pos1 - startCodeIndex - 3;
    printf("type = %d xpsLen= %d; outPos = %d, pos1 = %d\n", type, *xpsLen, *outPos, pos1);
}

#pragma mark - 解码

- (int)decodeVideoData:(unsigned char *)pData len:(int)len isInit:(BOOL)isInit {
    // NAL_UNIT_TYPpe  1:非idr的片;  5 idr
    if (pData == nil) {
        return -1;
    }
    
    self.type = DEC_264;
    
    [self initH264DecoderVideoData:pData len:len isInit:isInit];
    
    /* 确定nDiff值：
        Start Code表现形式：00 00 01 或 00 00 00 01
        Length表现形式：00 00 80 00
        有资料说当一帧图像被编码为多个slice（即需要有多个NALU）时，每个NALU的StartCode为3个字节，否则为4个字节
     */
    int nDiff = 0;
    int nalPackLen = len;
    unsigned char *pTemp = pData;
    for (int i = 0; i < len; i++) {
        if (*(pTemp) == 0 && *(pTemp + 1) == 0) {
            if (*(pTemp + 2) == 1) {                                // 00 00 01
                int nalu_type = ((uint8_t)*(pTemp + 3) & 0x1F);
                if (nalu_type == 1 || nalu_type == 5) {
                    nDiff = 3;
                    break;
                }
            } else if (*(pTemp + 2) == 0 && *(pTemp + 3) == 1) {    // 00 00 00 01
                int nalu_type = ((uint8_t)*(pTemp + 4) & 0x1F);
                
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
    
    // 非IDR图像的片、IDR图像的片
    if (nalu_type == 1 || nalu_type == 5) {
        if (nDiff == 3) {
            // 只有2个0 前面补位0
            if (innerLen <= nalPackLen) {
                innerLen = nalPackLen + 1;
                
                // void* realloc(void* ptr, unsigned newsize);
                // realloc是给一个已经分配了地址的指针重新分配空间,参数ptr为原有的空间地址,newsize是重新申请的地址长度
                pInnerData = (unsigned char *)realloc(pInnerData, innerLen);
            }
            
            memcpy(pInnerData + 1, pTemp, nalPackLen);
            pTemp = pInnerData;
            nalPackLen++;
        }
        
        // CMBlockBuffer：编码后，结果图像的数据结构(视频图像数据就是CMBlockBuffer)
        // A.CMBlockBufferCreateWithMemoryBlock:解码前将AVPacket的数据（网络抽象层单元数据，NALU）拷贝到CMBlockBuffer：
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
        const uint8_t sourceBytes[] = { (uint8_t)(reomveHeaderSize >> 24),
                                        (uint8_t)(reomveHeaderSize >> 16),
                                        (uint8_t)(reomveHeaderSize >> 8),
                                        (uint8_t)reomveHeaderSize };
        
        // B.用4字节长度代码（4 byte length code (the length of the NalUnit including the unit code)）替换分隔码（separator code）
        status = CMBlockBufferReplaceDataBytes(sourceBytes, videoBlock, 0, 4);
        
        // CMSampleBuffer包装了数据采样，就视频而言，CMSampleBuffer可包装压缩视频帧或未压缩视频帧，它组合了如下类型：CMTime（采样的显示时间）、CMVideoFormatDescription（描述了CMSampleBuffer包含的数据）、 CMBlockBuffer（对于压缩视频帧）、CMSampleBuffer（未压缩光栅化图像，可能包含在CVPixelBuffer或 CMBlockBuffer）
        CMSampleBufferRef sbRef = NULL;
        const size_t sampleSizeArray[] = {(size_t)len};
        
        // C. 由CMBlockBuffer创建CMSampleBuffer
        status = CMSampleBufferCreate(kCFAllocatorDefault,
                                      videoBlock,
                                      true,
                                      NULL,
                                      NULL,
                                      videoFormatDescr,
                                      1,
                                      0,
                                      NULL,
                                      1,
                                      sampleSizeArray,
                                      &sbRef);
        
        VTDecodeFrameFlags flags = 0;
        VTDecodeInfoFlags flagOut = 0;
        
        // D. 默认的同步解码一个视频帧,解码后的图像会交由didDecompress回调函数，来进一步的处理。
        status = VTDecompressionSessionDecodeFrame(decompressSession,
                                                   sbRef,
                                                   flags,
                                                   &sbRef,
                                                   &flagOut);
        if (status == noErr) {
            // Block until our callback has been called with the last frame
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
        // 释放解码会话
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
