//
//  CVPixelVideoDecoder.h
//  iMCU2
//
//  Created by admin on 15/2/14.
//
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import "KxMovieDecoder.h"

#define iMicroVideo 0

typedef enum {
    DEC_264,
    DEC_265,
}DecoderType;

@protocol HWVideoDecoderDelegate;

@interface HWVideoDecoder : NSObject

@property (nonatomic, assign) DecoderType type;
@property (nonatomic, assign) id<HWVideoDecoderDelegate> hwDelegate;

// 初始化视频解码器,并设置delegate
- (id)initWithDelegate:(id<HWVideoDecoderDelegate>)aDelegate;

// 解码视频数据
- (int)decodeVideoData:(unsigned char *)pH264Data len:(int)len;
//- (int)decodeVideoData:(unsigned char *)pH264Data len:(int)len width:(int)width height:(int)height;

// 关闭解码器，并释放资源
- (void)closeDecoder;

@end

@protocol HWVideoDecoderDelegate <NSObject>

-(void) getDecodePictureData:(KxVideoFrame *)frame;
-(void) getDecodePixelData:(CVImageBufferRef )frame;

@end
