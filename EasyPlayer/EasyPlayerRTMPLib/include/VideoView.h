
#import <UIKit/UIKit.h>


typedef enum {
    Stopped,    // 停止
    Connecting, // 连接中
    Rendering,  // 播放中
}IVideoStatus;


@protocol VideoViewDelegate <NSObject>

@optional
- (void)videoConnecting;    // 视频连接中
- (void)videoRendering;     // 视频播放中
- (void)videoStopped;       // 视频停止

@end


@interface VideoView : UIView<UIGestureRecognizerDelegate>

@property (nonatomic, weak) id<VideoViewDelegate> delegate;

@property (nonatomic, copy) NSString *url;              // 播放地址
@property (nonatomic, copy) NSString *snapshotPath;     // 保存最后一张画面地址
@property (nonatomic, copy) NSString *recordPath;       // 录像存储在沙盒的地址，为nil时再停止录像
@property (nonatomic, assign) BOOL isStopAudio;         // 是否关闭声音
@property (nonatomic, assign) BOOL isLandspace;         // 是否横屏
@property (nonatomic, assign) BOOL showAllRegon;        // 是否适配到屏幕宽高(默认适配)

@property (nonatomic, assign) IVideoStatus videoStatus;

// 播放控制
- (void)startPlay;
- (void)stopPlay;

// 音频控制
- (void)startAudio;
- (void)pauseAudio;
- (void)stopAudio;

/**
 截图
 
 @param path 截图存储在沙盒的地址
 */
- (void)screenShotWithPath:(NSString *)path;

@end
