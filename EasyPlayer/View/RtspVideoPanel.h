
#import <UIKit/UIKit.h>
#import "RtspVideoView.h"
#import "URLModel.h"

typedef NS_OPTIONS(NSInteger, IRtspVideoLayout) {
    IVL_One = 1,
    IVL_Four = 4,
    IVL_Nine = 9,
};

@protocol RtspVideoPanelDelegate;

@interface RtspVideoPanel : UIView

@property (nonatomic, weak) id<RtspVideoPanelDelegate> delegate;

@property (nonatomic, retain) NSMutableArray *resuedViews;
@property (nonatomic, strong) RtspVideoView *activeView;
@property (nonatomic, assign) IRtspVideoLayout layout;

- (RtspVideoView *) nextAvailableContainer;

// 重启全部视频的播放
- (void) restore;

// 停止全部视频的播放
- (void) stopAll;

// 开始全部视频的播放
- (void) startAll:(NSArray<URLModel *> *)urlModels;

// 设置分屏
- (void)setLayout:(IRtspVideoLayout)layout currentURL:(NSString *)url URLs:(NSArray<URLModel *> *)urlModels;

// 隐藏底部按钮
- (void) hideBtnView;

// 是否切换成横屏了
- (void) changeHorizontalScreen:(BOOL) horizontal;

@end

@protocol RtspVideoPanelDelegate <NSObject>

@optional
- (void) activeViewDidiUpdateStream:(RtspVideoView *)view;
- (void) didSelectVideoView:(RtspVideoView *)view;
- (void) activeVideoViewRendStatusChanged:(RtspVideoView *)view;

- (void) videoViewWillAnimateToFullScreen:(RtspVideoView *)view;
- (void) videoViewWillAnimateToNomarl:(RtspVideoView *)view;

// 添加新视频源
- (void) videoViewWillAddNewRes:(RtspVideoView *)view index:(int)index;

- (void) back;

@end
