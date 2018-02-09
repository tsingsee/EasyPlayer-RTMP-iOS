
#import "VideoPlayerController.h"
#import "RootViewController.h"
#import "UIColor+HexColor.h"
#import "VideoPanel.h"
#import "PureLayout.h"
#import "AudioManager.h"

//屏幕尺寸
#define SCREEN_HEIGHT ([UIScreen mainScreen].bounds.size.height)
#define SCREEN_WIDTH ([UIScreen mainScreen].bounds.size.width)

@interface VideoPlayerController () <VideoPanelDelegate> {
    UISegmentedControl *segment;
    
    CGRect panelFrame;
    
    BOOL crossScreen;   // 是否横屏
    BOOL fullScreen;    // 是否全屏
    BOOL firstFullScreen;   // 先全屏还是先横屏
}

@property (nonatomic, retain) NSMutableArray *URLs;
@property (nonatomic, strong) VideoPanel *panel;

@end

@implementation VideoPlayerController

#pragma mark - init

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 最多是9分屏，最多9个URL
    _URLs = [[NSMutableArray alloc] init];
    [_URLs addObject:_url];
    for (int i = 0; i < 8; i++) {
        [_URLs addObject:@""];
    }
    
    if ([[UIDevice currentDevice].systemVersion floatValue] >=7.0) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    self.navigationItem.title = @"播放";
    self.view.backgroundColor = [UIColor colorFromHex:0xfefefe];
    
    [[AudioManager sharedInstance] activateAudioSession];
    
    segment = [[UISegmentedControl alloc] initWithItems:@[@"一分屏", @"四分屏" ]];// , @"九分屏"
    segment.translatesAutoresizingMaskIntoConstraints = NO;
    segment.selectedSegmentIndex = 0;
    [segment addTarget:self action:@selector(layoutChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:segment];
    [segment autoPinEdgeToSuperviewEdge:ALEdgeLeading withInset:10];
    [segment autoPinEdgeToSuperviewEdge:ALEdgeTrailing withInset:10];
    [segment autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:5];
    [segment autoSetDimension:ALDimensionHeight toSize:35.0];
    
    panelFrame = CGRectMake(0, 45, SCREEN_WIDTH, SCREEN_WIDTH);
    self.panel = [[VideoPanel alloc] initWithFrame:panelFrame];
    self.panel.delegate = self;
    [self.view addSubview:self.panel];
    [self.panel setLayout:IVL_One currentURL:nil URLs:_URLs];
    
    [self regestAppStatusNotification];
    
    // 监听屏幕方向
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    // 当手机的重力感应打开的时候, 如果用户旋转手机, 系统会抛发UIDeviceOrientationDidChangeNotification 事件
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // 回归竖屏
    [self normalScreenWithDuration:0];
    
    [self stopAll];
}

- (void)dealloc {
    [[AudioManager sharedInstance] deactivateAudioSession];
    [self removeAppStutusNotification];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
}

#pragma mark - 根据屏幕状态，旋转UI

- (void)orientationChanged:(NSNotification *)notification {
    // 获取屏幕的方向
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    if (orientation == UIDeviceOrientationLandscapeRight) {// 右横屏
        if (!crossScreen) {
            crossScreen = YES;
            segment.hidden = YES;
            [self crossScreenWithDuration:0.5 isLeftCrossScreen:NO];
        }
    } else if (orientation == UIDeviceOrientationLandscapeLeft) {// 左横屏
        if (!crossScreen) {
            crossScreen = YES;
            segment.hidden = YES;
            [self crossScreenWithDuration:0.5 isLeftCrossScreen:YES];
        }
    } else if (orientation == UIDeviceOrientationPortrait) {// 正竖屏
        [self normalScreenWithDuration:0.5];
    }
}

#pragma mark - 横竖屏设置

- (void) crossScreenWithDuration:(NSTimeInterval)duration isLeftCrossScreen:(BOOL)isLeft {
    [UIView animateWithDuration:duration animations:^{
        [self.navigationController setNavigationBarHidden:YES];
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
        
        self.panel.frame = CGRectMake(0, 0, SCREEN_HEIGHT, SCREEN_WIDTH);
        self.panel.center = self.view.center;
        
        if (isLeft) {
            self.panel.transform = CGAffineTransformMakeRotation(M_PI_2);
        } else {
            self.panel.transform = CGAffineTransformMakeRotation(-M_PI_2);
        }
    }];
    
    // 只有一个VideoView时，横屏即是全屏
    if (segment.selectedSegmentIndex == 0) {
        VideoView *videoView = self.panel.resuedViews.firstObject;
        videoView.landspaceButton.selected = YES;
        segment.hidden = NO;
        fullScreen = YES;
        firstFullScreen = YES;
    }
}

- (void) normalScreenWithDuration:(NSTimeInterval)duration {
    crossScreen = NO;
    fullScreen = NO;
    
    segment.hidden = NO;
    segment.selectedSegmentIndex = segment.selectedSegmentIndex;
    [self layoutChanged:nil];
    
    [UIView animateWithDuration:duration animations:^{
        [self.navigationController setNavigationBarHidden:NO];
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
        
        self.panel.frame = panelFrame;
        self.panel.transform = CGAffineTransformIdentity;
    }];
    
    for (VideoView *v in self.panel.resuedViews) {
        v.landspaceButton.selected = NO;
    }
}

#pragma mark - click event

- (void)layoutChanged:(id)sender {
    if (segment.selectedSegmentIndex == 0) {
        [self.panel setLayout:IVL_One currentURL:nil URLs:_URLs];
    } else if (segment.selectedSegmentIndex == 1) {
        [self.panel setLayout:IVL_Four currentURL:nil URLs:_URLs];
    } else {
        [self.panel setLayout:IVL_Nine currentURL:nil URLs:_URLs];
    }
}

- (void)goBack:(id)sender {
    [self.panel stopAll];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)enterBackground {
    [[AudioManager sharedInstance] deactivateAudioSession];
    [self.panel stopAll];
}

#pragma mark - 播放控制

- (void) stopAll {
    [self.panel stopAll];
}

#pragma mark - VideoPanelDelegate

- (void)activeViewDidiUpdateStream:(VideoView *)view {
    
}

- (void)didSelectVideoView:(VideoView *)view {
    BOOL enable = view.videoStatus == Rendering;
    NSLog(@"%d", enable);
}

- (void)activeVideoViewRendStatusChanged:(VideoView *)view {
    
}

- (void)videoViewWillAddNewRes:(VideoView *)view index:(int)index {
    // 回归竖屏
    [self normalScreenWithDuration:0];
    
    RootViewController *vc = [[RootViewController alloc] init];
    vc.previewMore = ^(NSString *url) {
        [_URLs replaceObjectAtIndex:index withObject:url];
        
        [self.panel startAll:_URLs];
    };
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self.navigationController presentViewController:nav animated:YES completion:nil];
}

- (void)videoViewWillAnimateToFullScreen:(VideoView *)view {
    if (crossScreen) {      // 横屏->全屏
        [self.panel setLayout:IVL_One currentURL:view.url URLs:_URLs];// 先转成1分频
        firstFullScreen = NO;
    } else {            // 竖屏->全屏
        firstFullScreen = YES;
        [self.panel setLayout:IVL_One currentURL:view.url URLs:_URLs];// 先转成1分频
        [self crossScreenWithDuration:0.5 isLeftCrossScreen:YES];// 再全屏
    }
    
    fullScreen = YES;
    crossScreen = YES;
}

- (void)videoViewWillAnimateToNomarl:(VideoView *)view {
    if (fullScreen) {
        if (firstFullScreen) {
            // 全屏->竖屏
            if (segment.selectedSegmentIndex != 0) {
                segment.selectedSegmentIndex = segment.selectedSegmentIndex;
                [self layoutChanged:nil];
            }
            
            [self normalScreenWithDuration:0.5];
        } else {
            // 全屏->横屏
            segment.selectedSegmentIndex = segment.selectedSegmentIndex;
            [self layoutChanged:nil];
        }
    }
    
    fullScreen = NO;
}

#pragma mark - Notification

- (void)regestAppStatusNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(enterBackground)
                                                 name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(becomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)removeAppStutusNotification {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

#pragma mark - Notification 实现方法

- (void)becomeActive {
    [[AudioManager sharedInstance] activateAudioSession];
    [self.panel restore];
}

@end
