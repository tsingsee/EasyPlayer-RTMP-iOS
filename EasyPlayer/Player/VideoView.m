
#import "VideoView.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>
#import "UIColor+HexColor.h"
#import "KxMovieGLView.h"
#import "AudioManager.h"
#import "PathUnit.h"
#import "NSUserDefaultsUnit.h"
#import "WHToast.h"
#import "Masonry.h"

@interface VideoView() <UIScrollViewDelegate> {
    UIScrollView *scrollView;
    KxMovieGLView *kxGlView;
    UIActivityIndicatorView *activityIndicatorView;
    
    BOOL firstFrame;                // 得到第一帧，调整相关UI
    BOOL transforming;
    BOOL needChangeViewFrame;
    
    // 视频帧的宽高
    int displayWidth;
    int displayHeight;
    
    NSMutableArray *rgbFrameArray;  // 解码的视频数据
    NSMutableArray *_audioFrames;   // 解码的音频数据
    
    NSData  *_currentAudioFrame;    // 当前播放的音频帧
    NSUInteger _currentAudioFramePos;
    
    NSTimeInterval _tickCorrectionTime;
    NSTimeInterval _tickCorretionPosition;
    
    CGFloat _moviePosition;         // 当前播放视频的时间戳（毫秒为单位）
}

@property (nonatomic, strong) dispatch_source_t timer;
@property (nonatomic, assign) int frameLength;

@property (nonatomic, strong) UIView *statusView;
@property (nonatomic, strong) UIButton *playButton;     // 播放按钮

@property (nonatomic, strong) UIView *btnView;
@property (nonatomic, strong) UILabel *kbpsLabel;       // kbps
@property (nonatomic, strong) UIButton *audioButton;    // 声音按钮
@property (nonatomic, strong) UIButton *recordButton;   // 录像按钮
@property (nonatomic, strong) UIButton *screenshotButton;// 截屏按钮

@property (nonatomic, strong) UIView *backView;

@property (nonatomic, readwrite) CGFloat bufferdDuration;

@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property (nonatomic, strong) UITapGestureRecognizer *doubleTapGesture;

- (void)showActivity;
- (void)hideActivity;

- (void)fillAudioData:(SInt16 *)outData numFrames:(UInt32)numFrames numChannels:(UInt32)numChannels;

@end

@implementation VideoView

#pragma mark - init

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor blackColor];
        
        [self addGesture];
        [self addItemView];
        
        firstFrame = YES;
        self.videoStatus = Stopped;
        needChangeViewFrame = NO;
        _showActiveStatus = YES;
        
        self.useHWDecoder = ![NSUserDefaultsUnit isFFMpeg];
        self.audioPlaying = YES;
        
        rgbFrameArray = [[NSMutableArray alloc] init];
        _audioFrames = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void) addGesture {
    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    self.tapGesture.delegate = self;
    [self addGestureRecognizer:self.tapGesture];
}

- (void) addItemView {
    scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    [self addSubview:scrollView];
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.backgroundColor = [UIColor blackColor];
    scrollView.delegate = self;
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.zoomScale = 1;
    scrollView.minimumZoomScale = 1;
    scrollView.maximumZoomScale = 4.0;
    scrollView.bouncesZoom = NO;
    scrollView.bounces = NO;
    scrollView.scrollEnabled = NO;
    
    kxGlView = [[KxMovieGLView alloc] initWithFrame:CGRectMake(0, 0, 320, 240)];
    [scrollView addSubview:kxGlView];
    
    // 点击视频，隐藏底部按钮
    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideStatusView)];
    gesture.numberOfTapsRequired = 1;
    [kxGlView addGestureRecognizer:gesture];
    
    _addButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_addButton setImage:[UIImage imageNamed:@"ic_action_add"] forState:UIControlStateNormal];
    _addButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:_addButton];
    
    activityIndicatorView = [[UIActivityIndicatorView alloc] init];
    activityIndicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
    activityIndicatorView.hidesWhenStopped = YES;
    [self addSubview:activityIndicatorView];
    [activityIndicatorView makeConstraints:^(MASConstraintMaker *make) {
        make.size.equalTo(CGSizeMake(10, 10));
        make.centerX.equalTo(self.mas_centerX);
        make.centerY.equalTo(self.mas_centerY);
    }];
    
    CGFloat size = 45;
    
    _statusView = [[UIView alloc] init];
    _statusView.backgroundColor = UIColorFromRGB(0xf5f5f5);
    _statusView.hidden = YES;
    [self addSubview:_statusView];
    [_statusView makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(@0);
        make.height.equalTo(@(size));
    }];
    
    _playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_playButton setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
    [_playButton setImage:[UIImage imageNamed:@"pause"] forState:UIControlStateSelected];
    [_playButton addTarget:self action:@selector(playButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [_statusView addSubview:_playButton];
    [_playButton makeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(size));
        make.top.left.bottom.equalTo(@0);
    }];
    
    _btnView = [[UIView alloc] init];
    _btnView.backgroundColor = [UIColor clearColor];
    [_statusView addSubview:_btnView];
    [_btnView makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.right.equalTo(@0);
        make.left.equalTo(self.playButton.mas_right).offset(20);
    }];
    
    _kbpsLabel = [[UILabel alloc] init];
    _kbpsLabel.text = @"0kbps";
    _kbpsLabel.textColor = UIColorFromRGB(SelectBtnColor);
    _kbpsLabel.font = [UIFont systemFontOfSize:13];
    [_btnView addSubview:_kbpsLabel];
    [_kbpsLabel makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(@0);
        make.left.equalTo(@0);
    }];
    
    self.audioButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.audioButton setImage:[UIImage imageNamed:@"ic_action_audio_enabled"] forState:UIControlStateDisabled];
    [self.audioButton setImage:[UIImage imageNamed:@"ic_action_audio_enabled"] forState:UIControlStateNormal];
    [self.audioButton setImage:[UIImage imageNamed:@"ic_action_audio_pressed"] forState:UIControlStateSelected];
    [self.audioButton addTarget:self action:@selector(audioButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    self.audioButton.enabled = NO;
    _audioButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [_btnView addSubview:self.audioButton];
    [self.audioButton makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(@0);
        make.left.equalTo(self.kbpsLabel.mas_right);
    }];
    
    _recordButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_recordButton setImage:[UIImage imageNamed:@"ic_action_record_enabled"] forState:UIControlStateDisabled];
    [_recordButton setImage:[UIImage imageNamed:@"ic_action_record_enabled"] forState:UIControlStateNormal];
    [_recordButton setImage:[UIImage imageNamed:@"ic_action_record_pressed"] forState:UIControlStateSelected];
    [_recordButton addTarget:self action:@selector(recordButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    _recordButton.enabled = NO;
    _recordButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [_btnView addSubview:_recordButton];
    [_recordButton makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(@0);
        make.left.equalTo(self.audioButton.mas_right);
    }];
    
    _screenshotButton = [[UIButton alloc] init];
    [_screenshotButton setImage:[UIImage imageNamed:@"ic_action_camera_enabled"] forState:UIControlStateDisabled];
    [_screenshotButton setImage:[UIImage imageNamed:@"ic_action_camera_enabled"] forState:UIControlStateNormal];
    [_screenshotButton setImage:[UIImage imageNamed:@"ic_action_camera_pressed"] forState:UIControlStateHighlighted];
    [_screenshotButton addTarget:self action:@selector(screenshotButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    _screenshotButton.enabled = NO;
    _screenshotButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [_btnView addSubview:_screenshotButton];
    [_screenshotButton makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(@0);
        make.left.equalTo(self.recordButton.mas_right);
    }];
    
    _landspaceButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_landspaceButton setImage:[UIImage imageNamed:@"LandspaceVideo"] forState:UIControlStateNormal];
    [_landspaceButton setImage:[UIImage imageNamed:@"PortraitVideo"] forState:UIControlStateSelected];
    [_landspaceButton addTarget:self action:@selector(landspaceButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    _landspaceButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [_btnView addSubview:_landspaceButton];
    [_landspaceButton makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(@0);
        make.left.equalTo(self.screenshotButton.mas_right);
    }];
    
    NSArray *views = @[ self.kbpsLabel, self.audioButton, self.recordButton, self.screenshotButton, self.landspaceButton ];
    // 实现masonry水平固定间隔方法
    [views mas_distributeViewsAlongAxis:MASAxisTypeHorizontal withFixedSpacing:0 leadSpacing:0 tailSpacing:0];
    
    // 设置array的垂直方向的约束
    [views mas_makeConstraints:^(MASConstraintMaker *make) {
        
    }];
    
    _backView = [[UIView alloc] init];
    _backView.backgroundColor = UIColorFromRGBA(0x000000, 0.4);
    _backView.hidden = YES;
    [self addSubview:_backView];
    [_backView makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.equalTo(@0);
        make.height.equalTo(@44);
    }];
    
    UIButton *backBtn = [[UIButton alloc] init];
    [backBtn setImage:[UIImage imageNamed:@"nav_back"] forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
    [_backView addSubview:backBtn];
    [backBtn makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.equalTo(@0);
        make.left.equalTo(@15);
        make.width.equalTo(@44);
    }];
}

// 点击视频，隐藏底部按钮
- (void) hideStatusView {
    _statusView.hidden = !_statusView.hidden;
    
    // btnView没有隐藏，则不是分屏
    if (!self.btnView.isHidden) {
        if (_landspaceButton.isSelected) {// 横屏时
            _backView.hidden = _statusView.hidden;
        }
    }
}

- (void) changeHorizontalScreen:(BOOL) horizontal {
    _landspaceButton.selected = horizontal;
    
    [self updateHeight];
}

#pragma mark - override

- (void)layoutSubviews {
    [super layoutSubviews];
    
    _addButton.frame = self.bounds;
    
    if (_landspaceButton.selected) {
        kxGlView.frame = scrollView.bounds;
        scrollView.contentSize = scrollView.frame.size;
    } else {
        if (_showAllRegon) {
            CGRect rc = scrollView.frame;
            scrollView.contentSize = rc.size;
            if (displayWidth != 0 && displayHeight != 0) {
                int x = displayWidth > self.bounds.size.width ? 0 : (int)(fabs(self.bounds.size.width - displayWidth) / 2.0 + 0.5);
                int cx = MIN(displayWidth, self.bounds.size.width);
                int cy = MIN(displayHeight*cx/displayWidth, self.bounds.size.height);
                int y = (self.bounds.size.height - cy) / 2.0 + 0.5;
                
                CGRect imageRect;
                imageRect.origin = CGPointMake(x, y);
                imageRect.size = CGSizeMake(cx, cy);
                kxGlView.frame = imageRect;
            }
        } else {
            CGRect rc = scrollView.bounds;
            CGFloat width = rc.size.height * 16.0 / 9.0;
            if (displayHeight != 0 && displayWidth != 0) {
                width = rc.size.height * (float)displayWidth / (float)displayHeight;
                if (width < rc.size.width) {
                    width = rc.size.width;
                }
            }
            
            CGFloat height = rc.size.height;
            kxGlView.frame = CGRectMake(0, 0, width, height);
            scrollView.contentSize = CGSizeMake(width, height);
            NSLog(@"displayWidth = %d displayHeight = %d %f %f frameWidht = %f frameHeight = %f", displayWidth, displayHeight, width, height, self.frame.size.width, self.frame.size.height);
            scrollView.contentOffset = CGPointMake((width - rc.size.width) / 2, 0);
            
            [self reCalculateArcPos];
        }
    }
}

#pragma mark - 播放控制

- (void)startAudio {
    self.audioPlaying = YES;
    [AudioManager sharedInstance].sampleRate = _reader.mediaInfo.u32AudioSamplerate;
    [AudioManager sharedInstance].channel = _reader.mediaInfo.u32AudioChannel;
    [[AudioManager sharedInstance] play];
    __weak VideoView *weakSelf = self;
    [AudioManager sharedInstance].source = self;
    [AudioManager sharedInstance].outputBlock = ^(SInt16 *outData, UInt32 numFrames, UInt32 numChannels) {
        [weakSelf fillAudioData:outData numFrames:numFrames numChannels:numChannels];
    };
}

- (void)stopAudio {
    if ([AudioManager sharedInstance].source == self) {
        [[AudioManager sharedInstance] stop];
        [AudioManager sharedInstance].outputBlock = nil;
    }
    self.audioPlaying = NO;
}

- (void)startPlay {
    if (!self.url || self.url.length == 0) {
        return;
    }
    
    _tickCorrectionTime = 0;
    _tickCorretionPosition = 0;
    _moviePosition = 0;
    _currentAudioFramePos = 0;
    _bufferdDuration = 0;
    
    [self stopPlay];
    
    self.videoStatus = Connecting;
    [self showActivity];
    self.addButton.hidden = YES;
    [self.delegate videoViewWillTryToConnect:self];
    
    __weak VideoView *weakSelf = self;
    _reader = [[PlayerDataReader alloc] initWithUrl:self.url];
    _reader.useHWDecoder = self.useHWDecoder;
    _reader.transportMode = self.transportMode;
    _reader.sendOption = self.sendOption;
    
    if ([NSUserDefaultsUnit isAutoRecord]) {
        _reader.recordFilePath = [PathUnit recordWithURL:_url];
        _recordButton.selected = YES;
    }
    
    // 获得媒体类型
    _reader.fetchMediaInfoSuccessBlock = ^(void){
        weakSelf.videoStatus = Rendering;
        [weakSelf updateUI];
        [weakSelf presentFrame];
        
        // 自动播放声音
        if ([NSUserDefaultsUnit isAutoAudio]) {
            [weakSelf startAudio];
        }
    };
    
    // 获得解码后的音频帧／视频帧
    _reader.frameOutputBlock = ^(KxMovieFrame *frame, unsigned int length) {
        [weakSelf addFrame:frame];
        [weakSelf sendPacket:length];
    };
    [_reader start];
}

- (void)stopPlay {
    // 关闭前，停止录像
    _reader.recordFilePath = nil;
    
    [self screenShotName:YES];
    
    [self hideActivity];
    
    self.videoStatus = Stopped;
    
    dispatch_queue_t queue = dispatch_queue_create("stop_all_video", NULL);
    dispatch_async(queue, ^{
        [self stopAudio];
        [self.reader stop];
    });
    
    @synchronized(rgbFrameArray) {
        [rgbFrameArray removeAllObjects];
    }
    
    @synchronized(_audioFrames) {
        [_audioFrames removeAllObjects];
    }
    
    [self updateUI];
    [self flush];
}

- (void)flush {
    [kxGlView flush];
    firstFrame = YES;
    scrollView.zoomScale = 1.0;
    scrollView.scrollEnabled = NO;
}

- (void)updateUI {
    self.audioButton.enabled = self.videoStatus == Rendering ? YES : NO;
    _recordButton.enabled = self.videoStatus == Rendering ? YES : NO;
    _screenshotButton.enabled = self.videoStatus == Rendering ? YES : NO;
}

#pragma mark - 解码后的音频帧／视频帧

- (void)addFrame:(KxMovieFrame *)frame {
    if (frame.type == KxMovieFrameTypeVideo) {
        @synchronized(rgbFrameArray) {
            if (self.videoStatus != Rendering) {
                [rgbFrameArray removeAllObjects];
                return;
            }
            
            [rgbFrameArray addObject:frame];
            _bufferdDuration = frame.position - ((KxVideoFrameRGB *)rgbFrameArray.firstObject).position;
        }
    } else if (frame.type == KxMovieFrameTypeAudio) {
        @synchronized(_audioFrames) {
            if (!self.audioPlaying) {
                [_audioFrames removeAllObjects];
                return;
            }
            
            [_audioFrames addObject:frame];
        }
    }
}

#pragma mark - 填充视频数据

- (void)presentFrame {
    CGFloat duration = 0;
    
    if (self.videoStatus == Rendering) {
        NSTimeInterval time = 0.01;
        
        KxVideoFrame *frame = [self popVideoFrame];
        
        if (frame != nil) {
            duration = [self displayFrame:frame];
            
            NSTimeInterval correction = [self tickCorrection];
            
            NSTimeInterval interval = MAX(duration + correction, 0.01);
            
            if (interval >= 0.035) {
                interval = interval / 2;
            }
            
            time = interval;
        }
        
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^{
            [self presentFrame];
        });
    }
}

- (CGFloat)tickCorrection {
    if (_moviePosition == 0) {
        return 0;
    }
    
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    if (_tickCorrectionTime == 0) {
        _tickCorrectionTime = now;
        _tickCorretionPosition = _moviePosition;
        return 0;
    }
    
    NSTimeInterval dPosition = _moviePosition - _tickCorretionPosition;
    NSTimeInterval dTime = now - _tickCorrectionTime;
    NSTimeInterval correction = dPosition - dTime;
    
    if (correction > 1.f || correction < -1.f) {
        NSLog(@"tick correction reset %0.2f", correction);
        correction = 0;
        
        /* https://github.com/kolyvan/kxmovie
         * 这句不能设置0，否则一直play faster
         */
//        _tickCorrectionTime = 0;
    }
    
    if (_bufferdDuration >= 0.3) {
        NSLog(@"bufferdDuration = %f play faster", _bufferdDuration);
        correction = -1;
    }
    
    return correction;
}

- (KxVideoFrame *)popVideoFrame {   // 队列
    KxVideoFrame *frame = nil;
    @synchronized(rgbFrameArray) {
        if ([rgbFrameArray count] > 0) {
            frame = [rgbFrameArray firstObject];
            [rgbFrameArray removeObjectAtIndex:0];
        }
    }
    
    return frame;
}

- (CGFloat)displayFrame:(KxVideoFrame *)frame {
    if (frame.width != displayWidth || displayHeight != frame.height) {
        needChangeViewFrame = YES;
    }
    
    displayWidth = (int)frame.width;
    displayHeight = (int)frame.height;
    
    if ((self.videoStatus == Rendering) && firstFrame) {
        needChangeViewFrame = YES;
        firstFrame = NO;
        scrollView.scrollEnabled = YES;
        
        // 阻止iOS设备锁屏
        [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
        
        [self hideActivity];
    }
    
    if (needChangeViewFrame) {
        [self setNeedsLayout];
        needChangeViewFrame = NO;
    }
    
    [kxGlView render:frame];
    _moviePosition = frame.position;
    
    return frame.duration;
}

#pragma mark - 流量检测

- (void) sendPacket:(unsigned int)u32AVFrameLen {
    self.frameLength += u32AVFrameLen;
    
    if (!self.timer) {
        NSTimeInterval period = 1.0; // 设置时间间隔
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 0), period * NSEC_PER_SEC, 0);
        dispatch_source_set_event_handler(_timer, ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                self.kbpsLabel.text = [NSString stringWithFormat:@"%dkbps", self.frameLength / 1024 / 1024];
                self.frameLength = 0;
            });
        });
        
        dispatch_resume(self.timer);
    }
}

#pragma mark - 填充音频数据

- (void)fillAudioData:(SInt16 *) outData numFrames: (UInt32) numFrames numChannels: (UInt32) numChannels {
    @autoreleasepool {
        while (numFrames > 0) {
            if (_currentAudioFrame == nil) {
                @synchronized(_audioFrames) {
                    NSUInteger count = _audioFrames.count;
                    if (count > 0) {
                        KxAudioFrame *frame = _audioFrames[0];
                        CGFloat differ = _moviePosition - frame.position;

//                        // 似乎没有作用
//                        if (differ < -0.1) {
//                            memset(outData, 0, numFrames * numChannels * sizeof(float));
//                            break; // silence and exit
//                        }
                        
                        [_audioFrames removeObjectAtIndex:0];
                        
//                        if (differ > 5 && count > 1) {// 原来是5，结果音视频不同步，音频慢2秒左右
                        if (differ > 0.1 && count > 1) {
                            NSLog(@"differ = %.4f", differ);
                            NSLog(@"audio skip movPos = %.4f audioPos = %.4f", _moviePosition, frame.position);
                            continue;
                        }
                        
                        _currentAudioFramePos = 0;
                        _currentAudioFrame = frame.samples;
                    }
                }
            }
            
            if (_currentAudioFrame) {
                const void *bytes = (Byte *)_currentAudioFrame.bytes + _currentAudioFramePos;
                const NSUInteger bytesLeft = (_currentAudioFrame.length - _currentAudioFramePos);
                const NSUInteger frameSizeOf = numChannels * sizeof(SInt16);
                const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
                const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
                
                memcpy(outData, bytes, bytesToCopy);
                numFrames -= framesToCopy;
                outData += framesToCopy * numChannels;
                if (bytesToCopy < bytesLeft) {
                    _currentAudioFramePos += bytesToCopy;
                } else {
                    _currentAudioFrame = nil;
                }
            } else {
                memset(outData, 0, numFrames * numChannels * sizeof(SInt16));
                break;
            }
        }
    }
}

#pragma mark - public method

- (void)beginTransform {
    scrollView.contentOffset = CGPointZero;
    scrollView.zoomScale = 1;
    transforming = YES;
}

- (void)endTransform {
    transforming = NO;
}

- (void) hideBtnView {
    self.btnView.hidden = YES;
    _backView.hidden = YES;
}

#pragma mark - private method

- (void)updateStreamCount {
    [self.delegate videoViewDidiUpdateStream:self];
}

- (void)reCalculateArcPos {
    if (_landspaceButton.selected) {
        return;
    }
    
    CGFloat maxDiffer = scrollView.contentSize.width - scrollView.frame.size.width;
    if (maxDiffer <= 0 || self.videoStatus != Rendering) {
        return;
    } else {
        if (!firstFrame) {
            
        }
    }
}

- (void)showActivity {
    [self bringSubviewToFront:activityIndicatorView];
    [activityIndicatorView startAnimating];
}

- (void)hideActivity {
    [activityIndicatorView stopAnimating];
}

- (void) updateHeight {
    if (_landspaceButton.selected) {
        [_statusView updateConstraints:^(MASConstraintMaker *make) {
            make.height.equalTo(@56);
        }];
        
        _backView.hidden = NO;
    } else {
        [_statusView updateConstraints:^(MASConstraintMaker *make) {
            make.height.equalTo(@45);
        }];
        
        _backView.hidden = YES;
    }
    
    [_statusView layoutSubviews];
}

#pragma mark - 按钮事件

- (void)audioButtonClicked:(id)sender {
    self.audioButton.selected = !self.audioButton.selected;
    
    if (self.audioButton.selected) {
        [self startAudio];
    } else {
        self.audioPlaying = NO;
        [[AudioManager sharedInstance] pause];
        [AudioManager sharedInstance].outputBlock = nil;
    }
}

- (void)recordButtonClicked:(id)sender {
    _recordButton.selected = !_recordButton.selected;
    
    if (_recordButton.selected) {
        _reader.recordFilePath = [PathUnit recordWithURL:_url];
    } else {
        _reader.recordFilePath = nil;
    }
}

- (void) screenshotButtonClicked:(id)sender {
    if (_screenShotPath) {
        return;
    } else {
        [self screenShotName:NO];
    }
}

- (void) playButtonClicked:(id)sender {
    _playButton.selected = !_playButton.selected;
    
    if (!_playButton.selected) {
        [self startPlay];
    } else {
        [self stopPlay];
    }
}

- (void) landspaceButtonClicked:(id)sender {
    _landspaceButton.selected = !_landspaceButton.selected;
    
    [self.delegate videoViewBeginActive:self];
    if (_landspaceButton.selected) {
        [self.delegate videoViewWillAnimateToFullScreen:self];
    } else {
        [self.delegate videoViewWillAnimateToNomarl:self];
    }
    
    [self updateHeight];
}

- (void) back {
    [self.delegate back];
}

#pragma mark - 手势操作

- (void)handleTapGesture:(UITapGestureRecognizer *)tapGesture {
    [self.delegate videoViewBeginActive:self];
}

#pragma mark - setter

- (void)setVideoStatus:(IVideoStatus)videoStatus {
    _videoStatus = videoStatus;
}

- (void)setAudioPlaying:(BOOL)audioPlaying {
    _audioPlaying = audioPlaying;
    
    _reader.enableAudio = _audioPlaying;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.audioButton.selected = self.audioPlaying;
    });
}

- (void)setUrl:(NSString *)url {
    _url = url;
    
    _addButton.hidden = [_url length] == 0 ? NO : YES;
    
    if (url && [_url length] > 0) {
        _statusView.hidden = NO;
    } else {
        _statusView.hidden = YES;
    }
}

- (void)setShowActiveStatus:(BOOL)showActiveStatus {
    _showActiveStatus = showActiveStatus;
    self.layer.borderWidth = _active && _showActiveStatus ? 1 : 0;
}

- (void)setShowAllRegon:(BOOL)showAllRegon {
    _showAllRegon = showAllRegon;
    scrollView.scrollEnabled = _showAllRegon;
}

#pragma mark - getter

- (void) screenShotName:(BOOL)isSnapshot {
    // 保存图片到沙盒
    if (isSnapshot) {
        _screenShotPath = [PathUnit snapshotWithURL:_url];
    } else {
        _screenShotPath = [PathUnit screenShotWithURL:_url];
    }
    
    // 截屏
    if (_screenShotPath) {
        // 把图片直接保存到指定的路径（同时应该把图片的路径imagePath存起来，下次就可以直接用来取）
        [UIImagePNGRepresentation([kxGlView curImage]) writeToFile:_screenShotPath atomically:YES];
        _screenShotPath = nil;
        
        if (!isSnapshot) {
            [WHToast showMessage:@"截图保存成功" duration:1 finishHandler:nil];
        }
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView*)viewForZoomingInScrollView:(UIScrollView *)aScrollView {
    return nil;
}

- (void)scrollViewDidScroll:(UIScrollView *)aScrollView {
    if (transforming) {
        return;
    }
    
    CGPoint point = aScrollView.contentOffset;
    CGFloat maxX = aScrollView.contentSize.width - aScrollView.frame.size.width;
    if (point.x < 0.5) {
        point.x = 0.0;
        aScrollView.contentOffset = point;
    } else if ( point.x > maxX) {
        point.x = maxX;
        aScrollView.contentOffset = point;
    } else if (point.y < 0.5) {
        point.y = 0.0;
        aScrollView.contentOffset = point;
    } else if ( point.y > (aScrollView.contentSize.height - aScrollView.frame.size.height)) {
        point.y = aScrollView.contentSize.height - aScrollView.frame.size.height;
        aScrollView.contentOffset = point;
    }
    
    [self reCalculateArcPos];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([[touch view] isKindOfClass:[UIControl class]]) {
        return NO;
    }
    
    return YES;
}

@end
