
#import "VideoView.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>
#import "UIColor+HexColor.h"
#import "KxMovieGLView.h"
#import "PureLayout.h"
#import "AudioManager.h"
#import "PathUnit.h"
#import "NSUserDefaultsUnit.h"
#import "DC_AlertManager.h"

@interface VideoView() <UIScrollViewDelegate> {
    BOOL firstFrame;
    
    int displayWidth;
    int displayHeight;
    
    BOOL snapshoting;
    
    UIScrollView *scrollView;
    BOOL transforming;
    
    BOOL needChangeViewFrame;
    
    KxMovieGLView *kxGlView;
    
    CADisplayLink *displayLink;
    
    UIActivityIndicatorView *activityIndicatorView;
    UIView *statusView;
    UIButton *audioButton;      // 声音按钮
    UIButton *recordButton;     // 录像按钮
    UIButton *screenshotButton; // 截屏按钮
    UIButton *playButton;       // 播放按钮
    
    NSTimeInterval _tickCorrectionTime;
    NSTimeInterval _tickCorretionPosition;
    CGFloat _moviePosition;
    
    NSMutableArray *rgbFrameArray;
    NSMutableArray *_audioFrames;
    
    NSData  *_currentAudioFrame;
    NSUInteger _currentAudioFramePos;
}

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
    
    _addButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_addButton setImage:[UIImage imageNamed:@"ic_action_add"] forState:UIControlStateNormal];
    [self addSubview:_addButton];
    
    CGFloat size = 30;
    
    statusView = [UIView newAutoLayoutView];
    [self addSubview:statusView];
    [statusView autoPinEdgeToSuperviewEdge:ALEdgeLeading];
    [statusView autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
    [statusView autoPinEdgeToSuperviewEdge:ALEdgeBottom];
    [statusView autoSetDimension:ALDimensionHeight toSize:size];
    statusView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.35];
    statusView.hidden = YES;
    
    _landspaceButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [statusView addSubview:_landspaceButton];
    [_landspaceButton autoPinEdgeToSuperviewEdge:ALEdgeTrailing withInset:size * 0];
    [_landspaceButton autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:.0];
    [_landspaceButton autoSetDimensionsToSize:CGSizeMake(size, size)];
    [_landspaceButton setImage:[UIImage imageNamed:@"LandspaceVideo"] forState:UIControlStateNormal];
    [_landspaceButton setImage:[UIImage imageNamed:@"PortraitVideo"] forState:UIControlStateSelected];
    [_landspaceButton addTarget:self action:@selector(landspaceButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    
    audioButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [statusView addSubview:audioButton];
    [audioButton autoPinEdgeToSuperviewEdge:ALEdgeTrailing withInset:size * 1];
    [audioButton autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:0.0];
    [audioButton autoSetDimensionsToSize:CGSizeMake(size, size)];
    [audioButton setImage:[UIImage imageNamed:@"ic_action_audio"] forState:UIControlStateDisabled];
    [audioButton setImage:[UIImage imageNamed:@"ic_action_audio_enabled"] forState:UIControlStateNormal];
    [audioButton setImage:[UIImage imageNamed:@"ic_action_audio_pressed"] forState:UIControlStateSelected];
    [audioButton addTarget:self action:@selector(audioButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    audioButton.enabled = NO;
    
    screenshotButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [statusView addSubview:screenshotButton];
    [screenshotButton autoPinEdgeToSuperviewEdge:ALEdgeTrailing withInset:size * 2];
    [screenshotButton autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:.0];
    [screenshotButton autoSetDimensionsToSize:CGSizeMake(size, size)];
    [screenshotButton setImage:[UIImage imageNamed:@"ic_action_camera"] forState:UIControlStateDisabled];
    [screenshotButton setImage:[UIImage imageNamed:@"ic_action_camera_enabled"] forState:UIControlStateNormal];
    [screenshotButton setImage:[UIImage imageNamed:@"ic_action_camera_pressed"] forState:UIControlStateFocused];
    [screenshotButton addTarget:self action:@selector(screenshotButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    screenshotButton.enabled = NO;
    
    recordButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [statusView addSubview:recordButton];
    [recordButton autoPinEdgeToSuperviewEdge:ALEdgeTrailing withInset:size * 3];
    [recordButton autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:.0];
    [recordButton autoSetDimensionsToSize:CGSizeMake(size, size)];
    [recordButton setImage:[UIImage imageNamed:@"ic_action_record"] forState:UIControlStateDisabled];
    [recordButton setImage:[UIImage imageNamed:@"ic_action_record_enabled"] forState:UIControlStateNormal];
    [recordButton setImage:[UIImage imageNamed:@"ic_action_record_pressed"] forState:UIControlStateSelected];
    [recordButton addTarget:self action:@selector(recordButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    recordButton.enabled = NO;
    
    playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [statusView addSubview:playButton];
    [playButton autoPinEdgeToSuperviewEdge:ALEdgeLeading withInset:0];
    [playButton autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:.0];
    [playButton autoSetDimensionsToSize:CGSizeMake(size, size)];
    [playButton setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
    [playButton setImage:[UIImage imageNamed:@"pause"] forState:UIControlStateSelected];
    [playButton addTarget:self action:@selector(playButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    
    activityIndicatorView = [UIActivityIndicatorView newAutoLayoutView];
    activityIndicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
    activityIndicatorView.hidesWhenStopped = YES;
    [self addSubview:activityIndicatorView];
    [activityIndicatorView autoSetDimensionsToSize:CGSizeMake(10,10)];
    [activityIndicatorView autoAlignAxisToSuperviewAxis:ALAxisHorizontal];
    [activityIndicatorView autoAlignAxisToSuperviewAxis:ALAxisVertical];
}

#pragma mark - override

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat wh = 44;
    _addButton.frame = CGRectMake((self.bounds.size.width - wh) / 2, (self.bounds.size.height - wh) / 2, wh, wh);
    
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
    _reader = [[RtspDataReader alloc] initWithUrl:self.url];
    _reader.useHWDecoder = self.useHWDecoder;
    
    if ([NSUserDefaultsUnit isAutoRecord]) {
        _reader.recordFilePath = [PathUnit recordWithURL:_url];
        recordButton.selected = YES;
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
    _reader.frameOutputBlock = ^(KxMovieFrame *frame) {
        [weakSelf addFrame:frame];
    };
    [_reader start];
}

- (void)stopPlay {
    // 关闭前，停止录像
    _reader.recordFilePath = nil;
    
    [self screenShotName:YES];
    
    [self hideActivity];
    
    [displayLink invalidate];
    displayLink = nil;
    
    self.videoStatus = Stopped;
    
    dispatch_queue_t queue = dispatch_queue_create("stop_all_video", NULL);
    dispatch_async(queue, ^{
        [self stopAudio];
        [_reader stop];
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
    audioButton.enabled = self.videoStatus == Rendering ? YES : NO;
    recordButton.enabled = self.videoStatus == Rendering ? YES : NO;
    screenshotButton.enabled = self.videoStatus == Rendering ? YES : NO;
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
    
    NSTimeInterval dPos = _moviePosition - _tickCorretionPosition;
    NSTimeInterval dTime = now - _tickCorrectionTime;
    NSTimeInterval correction = dPos - dTime;
    if (correction > 0) {
        NSLog(@"tick correction reset %0.2f", correction);
        correction = 0;
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
    
    if (self.videoStatus == Rendering) {
        if (firstFrame) {
            needChangeViewFrame = YES;
            firstFrame = NO;
            scrollView.scrollEnabled = YES;
            [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
            [self hideActivity];
        }
    }
    
    if (needChangeViewFrame) {
        [self setNeedsLayout];
        needChangeViewFrame = NO;
    }
    
    [kxGlView render:frame];
    _moviePosition = frame.position;
    
    return frame.duration;
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
                        
                        [_audioFrames removeObjectAtIndex:0];
                        
                        if (differ > 5 && count > 1) {
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

#pragma mark - 按钮事件

- (void)audioButtonClicked:(id)sender {
    audioButton.selected = !audioButton.selected;
    
    if (audioButton.selected) {
        [self startAudio];
    } else {
        self.audioPlaying = NO;
        [[AudioManager sharedInstance] pause];
        [AudioManager sharedInstance].outputBlock = nil;
    }
}

- (void)recordButtonClicked:(id)sender {
    recordButton.selected = !recordButton.selected;
    
    if (recordButton.selected) {
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
    playButton.selected = !playButton.selected;
    
    if (!playButton.selected) {
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
        audioButton.selected = _audioPlaying;
    });
}

- (void)setUrl:(NSString *)url {
    _url = url;
    
    _addButton.hidden = [_url length] == 0 ? NO : YES;
    
    if (url && [_url length] > 0) {
        statusView.hidden = NO;
    } else {
        statusView.hidden = YES;
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
            [DC_AlertManager showHudWithMessage:@"截图保存成功"];
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
