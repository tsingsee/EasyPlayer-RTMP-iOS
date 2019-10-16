//
//  SplitScreenViewController.m
//  EasyPlayerRTMP
//
//  Created by leo on 2019/4/24.
//  Copyright © 2019年 cs. All rights reserved.
//

#import "SplitScreenViewController.h"
#import "RootViewController.h"
#import "VideoPanel.h"
#import "AudioManager.h"
#import "Masonry.h"
#import "NSUserDefaultsUnit.h"

@interface SplitScreenViewController ()<VideoPanelDelegate> {
    UISegmentedControl *segment;
    
    BOOL crossScreen;   // 是否横屏
    BOOL fullScreen;    // 是否全屏
    BOOL firstFullScreen;   // 先全屏还是先横屏
}

@property (nonatomic, retain) NSMutableArray *urlModels;
@property (nonatomic, strong) VideoPanel *panel;

@property (nonatomic, assign) BOOL statusBarHidden;
@property (nonatomic, assign) CGRect panelFrame;

@end

@implementation SplitScreenViewController

#pragma mark - init

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 最多是9分屏，最多9个URL
    _urlModels = [[NSMutableArray alloc] init];
    for (int i = 0; i < 9; i++) {
        [_urlModels addObject:[[MyURLModel alloc] initDefault]];
    }
    
    if ([[UIDevice currentDevice].systemVersion floatValue] >=7.0) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    self.navigationItem.title = @"分屏";
    self.view.backgroundColor = UIColorFromRGB(0xfefefe);
    
    [[AudioManager sharedInstance] activateAudioSession];
    
    segment = [[UISegmentedControl alloc] initWithItems:@[@"四分屏", @"九分屏" ]];// , @"九分屏"
    segment.translatesAutoresizingMaskIntoConstraints = NO;
    segment.selectedSegmentIndex = 0;
    [segment addTarget:self action:@selector(layoutChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:segment];
    [segment mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(@10);
        make.right.equalTo(@(-10));
        make.top.equalTo(@15);
        make.height.equalTo(@40);
    }];
    
    self.panelFrame = CGRectMake(0, 70, EasyScreenWidth, EasyScreenWidth);
    self.panel = [[VideoPanel alloc] initWithFrame:self.panelFrame];
    self.panel.delegate = self;
    [self.view addSubview:self.panel];
    [self.panel setLayout:IVL_Four URLs:_urlModels];
    [self.panel startAll:_urlModels];
    [self.panel hideBtnView];
    
    [self regestAppStatusNotification];
    
    // 监听屏幕方向
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    // 当手机的重力感应打开的时候, 如果用户旋转手机, 系统会抛发UIDeviceOrientationDidChangeNotification 事件
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [NSUserDefaultsUnit setAutoAudio:NO];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [NSUserDefaultsUnit setAutoAudio:YES];
    
    [self normalScreenWithDuration:0];// 回归竖屏
    
    [self.panel stopAll];
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
        self.statusBarHidden = NO;
        [self prefersStatusBarHidden];
        
        self.panel.frame = CGRectMake(0, 0, EasyScreenHeight, EasyScreenWidth);
        self.panel.center = self.view.center;
        
        if (isLeft) {
            self.panel.transform = CGAffineTransformMakeRotation(M_PI_2);
        } else {
            self.panel.transform = CGAffineTransformMakeRotation(-M_PI_2);
        }
        
        [self layoutChanged:nil];
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
        self.statusBarHidden = YES;
        [self prefersStatusBarHidden];
        
        self.panel.frame = self.panelFrame;
        self.panel.transform = CGAffineTransformIdentity;
        
        [self layoutChanged:nil];
    }];
    
    for (VideoView *v in self.panel.resuedViews) {
        v.landspaceButton.selected = NO;
    }
}

#pragma mark - click event

- (void)layoutChanged:(id)sender {
    if (segment.selectedSegmentIndex == 0) {
        [self.panel setLayout:IVL_Four URLs:_urlModels];
    } else if (segment.selectedSegmentIndex == 1) {
        [self.panel setLayout:IVL_Nine URLs:_urlModels];
    } else {
        [self.panel setLayout:IVL_One URLs:_urlModels];
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
    [self normalScreenWithDuration:0];// 回归竖屏
    
    RootViewController *vc = [[RootViewController alloc] initWithStoryboard];
    vc.previewMore = ^(MyURLModel *model) {
        model.useHWDecoder = ![NSUserDefaultsUnit isFFMpeg];
        model.isAutoAudio = [NSUserDefaultsUnit isAutoAudio];
        model.isAutoRecord = [NSUserDefaultsUnit isAutoRecord];
        [self.urlModels replaceObjectAtIndex:index withObject:model];
        [self.panel startAll:self.urlModels];
    };
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self.navigationController presentViewController:nav animated:YES completion:nil];
}

//- (void)videoViewWillAnimateToFullScreen:(VideoView *)view {
//    if (crossScreen) {      // 横屏->全屏
//        [self.panel setLayout:IVL_One URLs:_urlModels];// 先转成1分频
//        firstFullScreen = NO;
//    } else {            // 竖屏->全屏
//        firstFullScreen = YES;
//        [self.panel setLayout:IVL_One URLs:_urlModels];// 先转成1分频
//        [self crossScreenWithDuration:0.5 isLeftCrossScreen:YES];// 再全屏
//    }
//    
//    fullScreen = YES;
//    crossScreen = YES;
//}

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

#pragma mark - StatusBar

- (BOOL)prefersStatusBarHidden {
    return self.statusBarHidden;
}

@end
