
#import "VideoPanel.h"
#import "AudioManager.h"
#import "Masonry.h"

#define kContentInset 1

@interface VideoPanel() <VideoViewDelegate> {
    VideoView *_activeView;
    
    VideoView *primaryView;
    CGRect curPrimaryRect;
    
    BOOL startAnimate;
    BOOL willAnimateToPrimary;
}

@end

@implementation VideoPanel

#pragma mark - init

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        
        _resuedViews = [[NSMutableArray alloc] init];
    }
    
    return self;
}

#pragma mark - public method

- (VideoView *)nextAvailableContainer {
    int nIndex = -1;
    
    for (int i = 0; i < [_resuedViews count]; i++) {
        VideoView *videoView = [_resuedViews objectAtIndex:i];
        
        if (videoView.videoStatus == Stopped && videoView.active) {
            nIndex = i;
            break;
        }
    }
    
    VideoView *videoView = nil;
    
    if (nIndex >= 0) {
        videoView = [_resuedViews objectAtIndex:nIndex];
    } else {
        videoView = [_resuedViews firstObject];
    }
    
    return videoView;
}

- (void)stopAll {
    for (int i = 0; i < [_resuedViews count]; i++) {
        VideoView *videoView = [_resuedViews objectAtIndex:i];
        [videoView stopPlay];
    }
}

- (void)startAll:(NSArray<URLModel *> *)urlModels {
    for (int i = 0; i < [_resuedViews count]; i++) {
        URLModel *model = urlModels[i];
        
        VideoView *videoView = [_resuedViews objectAtIndex:i];
        videoView.url = model.url;
        videoView.transportMode = model.transportMode;
        videoView.sendOption = model.sendOption;
        
        [videoView startPlay];
    }
}

- (void)restore {
    for (int i = 0; i < [_resuedViews count]; i++) {
        VideoView *videoView = [_resuedViews objectAtIndex:i];
        
        if (videoView.videoStatus == Stopped) {
            [videoView startPlay];
        }
    }
}

#pragma mark - setter

- (void)setActiveView:(VideoView *)activeView {
    if (_activeView != activeView) {
        _activeView.active = NO;
        _activeView = activeView;
        _activeView.active = YES;
    }
}

- (void)setLayout:(IVideoLayout)layout currentURL:(NSString *)url URLs:(NSArray<URLModel *> *)urlModels {
//    if (_layout == layout) {
//        return;
//    }
    
    _layout = layout;
    
    NSInteger diff = _layout - [_resuedViews count];
    int count = (int)[_resuedViews count];
    
    for (int i = 0; i < diff; i++) {
        VideoView *videoView = [[VideoView alloc] init];
        videoView.delegate = self;
        [_resuedViews addObject:videoView];
        
        videoView.addButton.tag = i + count;
        [videoView.addButton addTarget:self action:@selector(addCameraRes:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    for (int i = (int)layout; i < [_resuedViews count]; i++) {
        VideoView *videoView = [_resuedViews objectAtIndex:i];
        if (videoView.videoStatus >= Connecting) {
            [videoView stopPlay];
            videoView.url = nil;
        }
    }
    
    for (int i = 0; i < [_resuedViews count]; i++) {
        VideoView *videoView = [_resuedViews objectAtIndex:i];
        if (videoView.superview != nil) {
            [videoView removeFromSuperview];
        }
    }
    
    BOOL hasActiveView = NO;
    VideoView *topView = nil;
    
    NSInteger rowCount = [self rowCount];       // 每行数
    NSInteger columnCount = _layout / rowCount; // 每列数
    
    CGFloat itemH, itemW;
    if (self.frame.size.height > self.frame.size.width) {
        itemH = self.frame.size.width / rowCount;
        itemW = self.frame.size.height / rowCount;
    } else {
        itemH = self.frame.size.height / rowCount;
        itemW = self.frame.size.width / rowCount;
    }
    
    for (int i = 0; i < rowCount; i++) {
        VideoView *leftView = nil;
        NSMutableArray *viewsOneRow = [[NSMutableArray alloc] init];
        
        for (int j = 0; j < columnCount; j++) {
            VideoView *view = [_resuedViews objectAtIndex:(i * columnCount + j)];
            [viewsOneRow addObject:view];
            [self addSubview:view];
            [view mas_updateConstraints:^(MASConstraintMaker *make) {
                make.size.equalTo(CGSizeMake(itemW, itemH));
            }];
            
            if (view.active) {
                hasActiveView = YES;
            }
            
            if (leftView == nil) {
                [view mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.left.equalTo(@0);
                }];

                if (topView == nil) {
                    [view mas_updateConstraints:^(MASConstraintMaker *make) {
                        make.top.equalTo(@0);
                    }];
                } else {
                    [view mas_makeConstraints:^(MASConstraintMaker *make) {
                        make.top.equalTo(topView.mas_bottom).offset(kContentInset);
                    }];
                }

                if (i == rowCount - 1) {
                    [view mas_makeConstraints:^(MASConstraintMaker *make) {
                        make.bottom.equalTo(@0);
                    }];
                }
                
                topView = view;
            } else {
                [view mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.left.equalTo(leftView.mas_right).offset(kContentInset);
                    make.top.equalTo(topView.mas_top);
                }];
            }
            
            if (j == columnCount - 1) {
                [view mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.right.equalTo(@0);
                }];
            }
            
            leftView = view;
        }
        
        leftView = nil;
    }
    
//    if (!hasActiveView) {
//        for (VideoView *view in _resuedViews) {
//            view.active = NO;
//        }
//
//        VideoView *view = [_resuedViews firstObject];
//        [self videoViewBeginActive:view];
//    }
    
    if (url) {
        // 全屏时，需要设置为1分屏, 并设置当前VideoView为第一个View
        VideoView *view = [_resuedViews firstObject];
        view.landspaceButton.selected = YES;
        view.url = url;
        [self videoViewBeginActive:view];
    } else {
        [self startAll:urlModels];
    }
}

- (void) hideBtnView {
    for (int i = 0; i < [_resuedViews count]; i++) {
        VideoView *videoView = [_resuedViews objectAtIndex:i];
        [videoView hideBtnView];
    }
}

- (void) changeHorizontalScreen:(BOOL) horizontal {
    for (int i = 0; i < [_resuedViews count]; i++) {
        VideoView *videoView = [_resuedViews objectAtIndex:i];
        [videoView changeHorizontalScreen:horizontal];
    }
}

#pragma mark - 点击事件

- (void)addCameraRes:(id)sender {
    UIButton *button = (UIButton *)sender;
    int index = (int)button.tag;
    
    VideoView *view = (VideoView *)button.superview;
    
    [self videoViewBeginActive:view];
    [self.delegate videoViewWillAddNewRes:view index:index];
}

#pragma mark - private method

- (int)rowCount {
    return (int)sqrt(self.layout);
}

- (CGFloat)cellWidth {
    CGSize size = [UIScreen mainScreen].bounds.size;
    return (size.width - kContentInset * [self insertCount]) / ([self insertCount] + 1);
}

- (CGFloat)cellHeight {
    return (self.frame.size.height - kContentInset * [self insertCount]) / ([self insertCount] + 1);
}

- (NSInteger)insertCount {
    NSInteger insetCount = 0;
    switch (self.layout) {
        case IVL_Four:
            insetCount = 1;
            break;
        case IVL_Nine:
            insetCount = 2;
            break;
        default:
            break;
    }
    
    return insetCount;
}

#pragma mark - VideoViewDelegate的事件

- (void)videoViewBeginActive:(VideoView *)view {
    [self setActiveView:view];
    [self.delegate didSelectVideoView:view];
}

- (void)videoViewWillAnimateToFullScreen:(VideoView *)view {
    [self.delegate videoViewWillAnimateToFullScreen:view];
}

- (void)videoViewWillAnimateToNomarl:(VideoView *)view {
    [self.delegate videoViewWillAnimateToNomarl:view];
}

- (void)videoView:(VideoView *)view response:(int)error {
    if (view == _activeView) {
        [self.delegate activeVideoViewRendStatusChanged:view];
    }
}

- (void)videoView:(VideoView *)view connectionBreak:(int)error {
    if (view == _activeView) {
        [self.delegate activeVideoViewRendStatusChanged:_activeView];
    }
}

- (void)videoViewWillTryToConnect:(VideoView *)view {
    if (view == _activeView) {
        [self.delegate activeVideoViewRendStatusChanged:_activeView];
    }
}

- (void)videoViewDidiUpdateStream:(VideoView *)view {
    if (view == _activeView) {
        [self.delegate activeViewDidiUpdateStream:_activeView];
    }
}

#pragma mark - dealloc

- (void)dealloc {
    
}

#pragma mark - override

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (startAnimate) {
        if (willAnimateToPrimary) {
            primaryView.frame = self.bounds;
        } else {
            primaryView.frame = primaryView.container.frame;
        }
        
        startAnimate = NO;
    }
}

@end
