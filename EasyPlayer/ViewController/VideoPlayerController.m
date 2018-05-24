
#import "VideoPlayerController.h"
#import "UIColor+HexColor.h"
#import "NSUserDefaultsUnit.h"
#import "PathUnit.h"
#import "Masonry.h"

// lib库的头文件
#import "AudioManager.h"
#import "VideoView.h"

//屏幕尺寸
#define SCREEN_HEIGHT ([UIScreen mainScreen].bounds.size.height)
#define SCREEN_WIDTH ([UIScreen mainScreen].bounds.size.width)

@interface VideoPlayerController ()<VideoViewDelegate> {
    BOOL crossScreen;   // 是否横屏
    BOOL fullScreen;    // 是否全屏
    BOOL firstFullScreen;   // 先全屏还是先横屏
    
    BOOL statusBarHidden;
}

@property (nonatomic, strong) VideoView *videoView;

@property (nonatomic, strong) UIView *statusView;
@property (nonatomic, strong) UIButton *playButton;       // 播放按钮
@property (nonatomic, strong) UIButton *audioButton;      // 声音按钮
@property (nonatomic, strong) UIButton *recordButton;     // 录像按钮
@property (nonatomic, strong) UIButton *screenshotButton; // 截屏按钮
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;

@end

@implementation VideoPlayerController

#pragma mark - init

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ([[UIDevice currentDevice].systemVersion floatValue] >=7.0) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    self.navigationItem.title = @"播放";
    self.view.backgroundColor = [UIColor colorFromHex:0x000000];
    
    // ------------- 3.开启声音Session -------------
    [[AudioManager sharedInstance] activateAudioSession];
    
    // ------------- 4.初始化播放器VideoView -------------
    CGFloat height = [[UIApplication sharedApplication] statusBarFrame].size.height + 44;
    CGRect frame = CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT - height);
    self.videoView = [[VideoView alloc] initWithFrame:frame];
    [self.view addSubview:self.videoView];
    
    [self addItemView];
    
    // ------------- 5.设置播放器的属性 -------------
    self.videoView.delegate = self;     // 播放状态的代理
    self.videoView.url = self.url;      // 流地址
    self.videoView.showAllRegon = YES;  // 适配到屏幕宽高
    self.videoView.isStopAudio = NO;    // 关闭声音
    self.videoView.useHWDecoder = NO;   // 使用软解码
    self.videoView.snapshotPath = [PathUnit snapshotWithURL:_url];  // 为空，则不保存最后一帧画面
    
    // ------------- 7.添加App状态通知来关闭/打开视频 -------------
    [self regestAppStatusNotification];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // ------------- 6.开始播放 -------------
    [self.videoView startPlay];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // ------------- 8.停止播放 -------------
    [self.videoView stopPlay];
}

- (void)dealloc {
    [[AudioManager sharedInstance] deactivateAudioSession];
    [self removeAppStutusNotification];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
}

#pragma mark - 添加UI

// 添加按钮
- (void) addItemView {
    CGFloat size = 30;
    
    self.statusView = [[UIView alloc] init];
    self.statusView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
    [self.view addSubview:self.statusView];
    [self.statusView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(@0);
        make.right.equalTo(@0);
        make.bottom.equalTo(@0);
        make.height.equalTo(@60);
    }];
    
    self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.playButton setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
    [self.playButton setImage:[UIImage imageNamed:@"pause"] forState:UIControlStateSelected];
    [self.playButton addTarget:self action:@selector(playButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.statusView addSubview:self.playButton];
    [self.playButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(@0).offset(15);
        make.centerY.equalTo(self.statusView);
        make.size.equalTo(@(CGSizeMake(size, size)));
    }];
    
    self.audioButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.audioButton setImage:[UIImage imageNamed:@"ic_action_audio"] forState:UIControlStateDisabled];
    [self.audioButton setImage:[UIImage imageNamed:@"ic_action_audio_enabled"] forState:UIControlStateNormal];
    [self.audioButton setImage:[UIImage imageNamed:@"ic_action_audio_pressed"] forState:UIControlStateSelected];
    [self.audioButton addTarget:self action:@selector(audioButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.statusView addSubview:self.audioButton];
    [self.audioButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.playButton.mas_right).offset(15);
        make.centerY.equalTo(self.statusView);
        make.size.equalTo(@(CGSizeMake(size, size)));
    }];
    self.audioButton.selected = YES;
    
    self.screenshotButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.screenshotButton setImage:[UIImage imageNamed:@"ic_action_camera"] forState:UIControlStateDisabled];
    [self.screenshotButton setImage:[UIImage imageNamed:@"ic_action_camera_enabled"] forState:UIControlStateNormal];
    [self.screenshotButton setImage:[UIImage imageNamed:@"ic_action_camera_pressed"] forState:UIControlStateFocused];
    [self.screenshotButton addTarget:self action:@selector(screenshotButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.statusView addSubview:self.screenshotButton];
    [self.screenshotButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.audioButton.mas_right).offset(15);
        make.centerY.equalTo(self.statusView);
        make.size.equalTo(@(CGSizeMake(size, size)));
    }];
    
    self.recordButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.recordButton setImage:[UIImage imageNamed:@"ic_action_record"] forState:UIControlStateDisabled];
    [self.recordButton setImage:[UIImage imageNamed:@"ic_action_record_enabled"] forState:UIControlStateNormal];
    [self.recordButton setImage:[UIImage imageNamed:@"ic_action_record_pressed"] forState:UIControlStateSelected];
    [self.recordButton addTarget:self action:@selector(recordButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.statusView addSubview:self.recordButton];
    [self.recordButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.screenshotButton.mas_right).offset(15);
        make.centerY.equalTo(self.statusView);
        make.size.equalTo(@(CGSizeMake(size, size)));
    }];
    
    self.activityIndicatorView = [[UIActivityIndicatorView alloc] init];
    self.activityIndicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
    [self.statusView addSubview:self.activityIndicatorView];
    [self.activityIndicatorView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(@0);
        make.centerY.equalTo(self.statusView);
        make.size.equalTo(@(CGSizeMake(size, size)));
    }];
}

#pragma mark - click event

- (void)goBack:(id)sender {
    [self.videoView stopPlay];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)audioButtonClicked:(id)sender {
    self.audioButton.selected = !self.audioButton.selected;
    
    if (self.audioButton.selected) {
        [self.videoView startAudio];
    } else {
        [[AudioManager sharedInstance] pause];
        [AudioManager sharedInstance].outputBlock = nil;
    }
}

- (void)recordButtonClicked:(id)sender {
    self.recordButton.selected = !self.recordButton.selected;
    
    if (self.recordButton.selected) {
        self.videoView.recordPath = [PathUnit recordWithURL:_url];
    } else {
        self.videoView.recordPath = nil;
    }
}

- (void) screenshotButtonClicked:(id)sender {
    [self.videoView screenShotWithPath:[PathUnit screenShotWithURL:_url]];
}

- (void) playButtonClicked:(id)sender {
    self.playButton.selected = !self.playButton.selected;
    
    if (!self.playButton.selected) {
        [self.videoView startPlay];
    } else {
        [self.videoView stopPlay];
    }
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
    // ------------- 6.开始播放 -------------
    [[AudioManager sharedInstance] activateAudioSession];
    [self.videoView startPlay];
}

- (void)enterBackground {
    // ------------- 8.停止播放 -------------
    [[AudioManager sharedInstance] deactivateAudioSession];
    [self.videoView stopPlay];
}

#pragma mark - StatusBar

- (BOOL)prefersStatusBarHidden {
    return statusBarHidden;
}

#pragma mark - VideoViewDelegate

// 视频连接中
- (void)videoConnecting {
    self.playButton.enabled = NO;
    self.audioButton.enabled = NO;
    self.screenshotButton.enabled = NO;
    self.recordButton.enabled = NO;
    
    [self.activityIndicatorView startAnimating];
}

// 视频播放中
- (void)videoRendering {
    self.playButton.enabled = YES;
    self.audioButton.enabled = YES;
    self.screenshotButton.enabled = YES;
    self.recordButton.enabled = YES;
    
    [self.activityIndicatorView stopAnimating];
}

// 视频停止
- (void)videoStopped {
    self.audioButton.enabled = NO;
    self.screenshotButton.enabled = NO;
    self.recordButton.enabled = NO;
}

@end
