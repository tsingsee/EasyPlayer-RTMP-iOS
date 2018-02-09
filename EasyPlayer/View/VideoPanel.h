
#import <UIKit/UIKit.h>
#import "VideoView.h"

typedef NS_OPTIONS(NSInteger, IVideoLayout){
    IVL_One = 1,
    IVL_Four = 4,
    IVL_Nine = 9,
};

@protocol VideoPanelDelegate;

@interface VideoPanel : UIView

@property (nonatomic, weak) id<VideoPanelDelegate> delegate;

@property (nonatomic, retain) NSMutableArray *resuedViews;
@property (nonatomic, strong) VideoView *activeView;
@property (nonatomic, assign) IVideoLayout layout;

- (VideoView *) nextAvailableContainer;

// 重启全部视频的播放
- (void) restore;

// 停止全部视频的播放
- (void) stopAll;

// 开始全部视频的播放
- (void) startAll:(NSMutableArray *)URLs;

// 设置分屏
- (void)setLayout:(IVideoLayout)layout currentURL:(NSString *)url URLs:(NSMutableArray *)urls;

@end

@protocol VideoPanelDelegate <NSObject>

@optional
- (void) activeViewDidiUpdateStream:(VideoView *)view;
- (void) didSelectVideoView:(VideoView *)view;
- (void) activeVideoViewRendStatusChanged:(VideoView *)view;

- (void) videoViewWillAnimateToFullScreen:(VideoView *)view;
- (void) videoViewWillAnimateToNomarl:(VideoView *)view;

// 添加新视频源
- (void) videoViewWillAddNewRes:(VideoView *)view index:(int)index;

@end
