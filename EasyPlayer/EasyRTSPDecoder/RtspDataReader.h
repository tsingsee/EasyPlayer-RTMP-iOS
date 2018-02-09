
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "KxMovieDecoder.h"

#include "EasyRTMPClientAPI.h"

/**
 获取RTSP流，解协议,解封装,再分别音视频解码
 */
@interface RtspDataReader : NSObject

@property (nonatomic, copy) NSString *url;              // 流媒体地址
@property (nonatomic, readonly) BOOL running;           // 播放中

@property (nonatomic)BOOL enableAudio;
@property (nonatomic)BOOL useHWDecoder; // 是否启用硬解码

@property (nonatomic, copy) NSString *recordFilePath;   // 录像地址

// 获得媒体类型
@property (nonatomic, copy) void (^fetchMediaInfoSuccessBlock)(void);

// 获得解码后的音频帧／视频帧
@property (nonatomic, copy) void (^frameOutputBlock)(KxMovieFrame *frame);

+ (void)startUp;

- (id)initWithUrl:(NSString *)url;
- (void)start;
- (void)stop;

- (EASY_MEDIA_INFO_T)mediaInfo;

@end
