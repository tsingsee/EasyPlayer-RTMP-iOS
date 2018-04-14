
#import "RtspDataReader.h"
#import "PathUnit.h"

#include <pthread.h>
#include <vector>
#include <set>
#include <string.h>

#import "HWVideoDecoder.h"
#include "VideoDecode.h"
#include "EasyAudioDecoder.h"

#include "Muxer.h"

struct FrameInfo {
    FrameInfo() : pBuf(NULL), frameLen(0), type(0), timeStamp(0), width(0), height(0){}
    
    unsigned char *pBuf;
    int frameLen;
    int type;
    CGFloat timeStamp;
    int width;
    int height;
};

class compare {
public:
    bool operator ()(FrameInfo *lhs, FrameInfo *rhs) const {
        return lhs->timeStamp < rhs->timeStamp;
    }
};

pthread_mutex_t mutexRecordVideoFrame;
pthread_mutex_t mutexRecordAudioFrame;

std::multiset<FrameInfo *, compare> recordVideoFrameSet;
std::multiset<FrameInfo *, compare> recordAudioFrameSet;

int isKeyFrame = 0; // 是否到了I帧
int *stopRecord = (int *)malloc(sizeof(int));// 停止录像

@interface RtspDataReader()<HWVideoDecoderDelegate> {
    // RTSP拉流句柄
    Easy_RTSP_Handle rtspHandle;
    
    // 互斥锁
    pthread_mutex_t mutexVideoFrame;
    pthread_mutex_t mutexAudioFrame;
    pthread_mutex_t mutexChan;
    
    void *_videoDecHandle;  // 视频解码句柄
    void *_audioDecHandle;  // 音频解码句柄
    
    EASY_MEDIA_INFO_T _mediaInfo;   // 媒体信息
    
    std::multiset<FrameInfo *, compare> videoFrameSet;
    std::multiset<FrameInfo *, compare> audioFrameSet;
    
    CGFloat lastFrameTimeStamp;
    NSTimeInterval beforeDecoderTimeStamp;
    NSTimeInterval afterDecoderTimeStamp;
    
    CGFloat _lastVideoFramePosition;
    
    // 视频硬解码器
    HWVideoDecoder *_hwDec;
}

@property (nonatomic, readwrite) BOOL running;
@property (nonatomic, strong) NSThread *videoThread;
@property (nonatomic, strong) NSThread *audioThread;

- (void)pushFrame:(char *)pBuf frameInfo:(EASY_FRAME_INFO *)info type:(int)type;
- (void)recvMediaInfo:(EASY_MEDIA_INFO_T *)info;

@end

#pragma mark - 拉流后的回调

/*
 _channelId:    通道号,暂时不用
 _channelPtr:   通道对应对象
 _frameType:    EASY_SDK_VIDEO_FRAME_FLAG/EASY_SDK_AUDIO_FRAME_FLAG/EASY_SDK_EVENT_FRAME_FLAG/...
 _pBuf:         回调的数据部分，具体用法看Demo
 _frameInfo:    帧结构数据
 */
int RTSPDataCallBack(int channelId, void *channelPtr, int frameType, char *pBuf, EASY_FRAME_INFO *frameInfo) {
    if (channelPtr == NULL) {
        return 0;
    }
    
    if (pBuf == NULL) {
        return 0;
    }
    
    RtspDataReader *reader = (__bridge RtspDataReader *)channelPtr;
    
    if (frameInfo != NULL) {
        if (frameType == EASY_SDK_AUDIO_FRAME_FLAG) {// EASY_SDK_AUDIO_FRAME_FLAG音频帧标志
            [reader pushFrame:pBuf frameInfo:frameInfo type:frameType];
        } else if (frameType == EASY_SDK_VIDEO_FRAME_FLAG &&    // EASY_SDK_VIDEO_FRAME_FLAG视频帧标志
                   frameInfo->codec == EASY_SDK_VIDEO_CODEC_H264) { // H264视频编码
            [reader pushFrame:pBuf frameInfo:frameInfo type:frameType];
        }
    } else {
        if (frameType == EASY_SDK_MEDIA_INFO_FLAG) {// EASY_SDK_MEDIA_INFO_FLAG媒体类型标志
            EASY_MEDIA_INFO_T mediaInfo = *((EASY_MEDIA_INFO_T *)pBuf);
            NSLog(@"RTMP DESCRIBE Get Media Info: video:%u fps:%u audio:%u channel:%u sampleRate:%u \n",
                  mediaInfo.u32VideoCodec,
                  mediaInfo.u32VideoFps,
                  mediaInfo.u32AudioCodec,
                  mediaInfo.u32AudioChannel,
                  mediaInfo.u32AudioSamplerate);
            [reader recvMediaInfo:&mediaInfo];
        }
    }
    
    return 0;
}

@implementation RtspDataReader

+ (void)startUp {
    DecodeRegiestAll();
}

#pragma mark - init

- (id)initWithUrl:(NSString *)url {
    if (self = [super init]) {
        // 动态方式是采用pthread_mutex_init()函数来初始化互斥锁
        pthread_mutex_init(&mutexVideoFrame, 0);
        pthread_mutex_init(&mutexAudioFrame, 0);
        pthread_mutex_init(&mutexChan, 0);
        pthread_mutex_init(&mutexRecordVideoFrame, 0);
        pthread_mutex_init(&mutexRecordAudioFrame, 0);
        
        _videoDecHandle = NULL;
        _audioDecHandle = NULL;
        
        self.url = url;
        
        // 初始化硬解码器
        _hwDec = [[HWVideoDecoder alloc] initWithDelegate:self];
    }
    
    return self;
}

#pragma mark - public method

- (void)start {
    if (self.url.length == 0) {
        return;
    }
    
    _lastVideoFramePosition = 0;
    _running = YES;
    
    self.videoThread = [[NSThread alloc] initWithTarget:self selector:@selector(videoThreadFunc) object:nil];
    [self.videoThread start];
    
    self.audioThread = [[NSThread alloc] initWithTarget:self selector:@selector(audioThreadFunc) object:nil];
    [self.audioThread start];
}

- (void)stop {
    if (!_running) {
        return;
    }
    
    pthread_mutex_lock(&mutexChan);
    if (rtspHandle != NULL) {
        EasyRTMPClient_SetCallback(rtspHandle, NULL);
        EasyRTMPClient_Release(rtspHandle);
    }
    pthread_mutex_unlock(&mutexChan);
    
    _running = false;
    [self.videoThread cancel];
    [self.audioThread cancel];
}

#pragma mark - 子线程方法

- (void) initRtspHandle {
    // ------------ 加锁mutexChan ------------
    pthread_mutex_lock(&mutexChan);
    if (rtspHandle == NULL) {
        rtspHandle = EasyRTMPClient_Create();
        // EasyRTMP_Init(&rtspHandle);
        if (rtspHandle == NULL) {
            NSLog(@"EasyRTMP_Init err");
        } else {
            /* 设置数据回调 */
            EasyRTMPClient_SetCallback(rtspHandle, RTSPDataCallBack);
            
            /* 打开网络流 */
            EasyRTMPClient_StartStream(rtspHandle,
                                       1,
                                       (char *)[self.url UTF8String],
                                       (__bridge void *)self);
        }
    }
    pthread_mutex_unlock(&mutexChan);
    // ------------ 解锁mutexChan ------------
}

- (void)audioThreadFunc {
    // 在播放中 该线程一直运行
    while (_running) {
        if (rtspHandle == NULL) {
            continue;
        }
        
        // ------------ 加锁mutexAudioFrame ------------
        pthread_mutex_lock(&mutexAudioFrame);
        
        int count = (int) audioFrameSet.size();
        if (count == 0) {
            pthread_mutex_unlock(&mutexAudioFrame);
            usleep(5 * 1000);
            continue;
        }
        
        FrameInfo *frame = *(audioFrameSet.begin());
        audioFrameSet.erase(audioFrameSet.begin());// erase()函数的功能是用来删除容器中的元素
        
        pthread_mutex_unlock(&mutexAudioFrame);
        // ------------ 解锁mutexAudioFrame ------------
        
        if (self.enableAudio) {
            [self decodeAudioFrame:frame];
        }
        
        delete []frame->pBuf;
        delete frame;
    }
    
    [self removeAudioFrameSet];
    
    if (_audioDecHandle != NULL) {
        EasyAudioDecodeClose((EasyAudioHandle *)_audioDecHandle);
        _audioDecHandle = NULL;
    }
}

- (void)videoThreadFunc {
    // 在播放中 该线程一直运行
    while (_running) {
        [self initRtspHandle];
        
        // ------------ 加锁mutexVideoFrame ------------
        pthread_mutex_lock(&mutexVideoFrame);
        
        int count = (int) videoFrameSet.size();
        if (count == 0) {
            pthread_mutex_unlock(&mutexVideoFrame);
            usleep(5 * 1000);
            continue;
        }
        
        FrameInfo *frame = *(videoFrameSet.begin());
        videoFrameSet.erase(videoFrameSet.begin());// erase()函数的功能是用来删除容器中的元素
        
        beforeDecoderTimeStamp = [[NSDate date] timeIntervalSince1970] * 1000;// 毫秒数
        
        pthread_mutex_unlock(&mutexVideoFrame);
        // ------------ 解锁mutexVideoFrame ------------
        
        if (self.useHWDecoder) {
            [_hwDec decodeVideoData:frame->pBuf len:frame->frameLen];
        } else {
            [self decodeVideoFrame:frame];
        }
        
        delete []frame->pBuf;
        
        // 帧里面有个timestamp 是当前帧的时间戳， 先获取下系统时间A，然后解码播放，解码后获取系统时间B， B-A就是本次的耗时。sleep的时长就是 当期帧的timestamp  减去 上一个视频帧的timestamp 再减去 这次的耗时
        afterDecoderTimeStamp = [[NSDate date] timeIntervalSince1970] * 1000;
        if (lastFrameTimeStamp != 0) {
            float t = frame->timeStamp - lastFrameTimeStamp - (afterDecoderTimeStamp - beforeDecoderTimeStamp);
            usleep(t);
        }
        
        lastFrameTimeStamp = frame->timeStamp;
        
        delete frame;
    }
    
    [self removeVideoFrameSet];
    
    if (_videoDecHandle != NULL) {
        DecodeClose(_videoDecHandle);
        _videoDecHandle = NULL;
    }
    
    if (self.useHWDecoder) {
        [_hwDec closeDecoder];
    }
}

#pragma mark - 解码视频帧

- (void)decodeVideoFrame:(FrameInfo *)video {
    if (_videoDecHandle == NULL) {
        DEC_CREATE_PARAM param;
        param.nMaxImgWidth = video->width;
        param.nMaxImgHeight = video->height;
        param.coderID = CODER_H264;
        param.method = IDM_SW;
        _videoDecHandle = DecodeCreate(&param);
    }
    
    DEC_DECODE_PARAM param;
    param.pStream = video->pBuf;
    param.nLen = video->frameLen;
    param.need_sps_head = false;
    
    DVDVideoPicture picture;
    memset(&picture, 0, sizeof(picture));
    picture.iDisplayWidth = video->width;
    picture.iDisplayHeight = video->height;
    
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    int nRet = DecodeVideo(_videoDecHandle, &param, &picture);
    
    NSTimeInterval decodeInterval = 1000.0 * ([NSDate timeIntervalSinceReferenceDate] - now);
    
    if (nRet) {
        @autoreleasepool {
            KxVideoFrameRGB *frame = [[KxVideoFrameRGB alloc] init];
            frame.width = param.nOutWidth;
            frame.height = param.nOutHeight;
            frame.linesize = param.nOutWidth * 3;
            frame.hasAlpha = NO;
            frame.rgb = [NSData dataWithBytes:param.pImgRGB length:param.nLineSize * param.nOutHeight];
            frame.position = video->timeStamp / 1000.0;
            
            if (_lastVideoFramePosition == 0) {
                _lastVideoFramePosition = video->timeStamp;
            }
            
            CGFloat duration = (video->timeStamp - _lastVideoFramePosition - decodeInterval) / 1000.0;
            if (duration >= 1.0 || duration <= -1.0) {
                duration = 0.02;
            }
            frame.duration = duration;
            
            _lastVideoFramePosition = video->timeStamp;
            
            afterDecoderTimeStamp = [[NSDate date] timeIntervalSince1970] * 1000;
            
            if (self.frameOutputBlock) {
                self.frameOutputBlock(frame);
            }
        }
    }
}

#pragma mark - 解码音频帧

- (void)decodeAudioFrame:(FrameInfo *)audio {
    if (_audioDecHandle == NULL) {
        _audioDecHandle = EasyAudioDecodeCreate(_mediaInfo.u32AudioCodec,
                                                _mediaInfo.u32AudioSamplerate,
                                                _mediaInfo.u32AudioChannel,
                                                16);
    }
    
    unsigned char pcmBuf[10 * 1024] = { 0 };
    int pcmLen = 0;
    int ret = EasyAudioDecode((EasyAudioHandle *)_audioDecHandle,
                              audio->pBuf,
                              0,
                              audio->frameLen,
                              pcmBuf,
                              &pcmLen);
    if (ret == 0) {
        @autoreleasepool {
            KxAudioFrame *frame = [[KxAudioFrame alloc] init];
            frame.samples = [NSData dataWithBytes:pcmBuf length:pcmLen];
            frame.position = audio->timeStamp / 1000.0;
            if (self.frameOutputBlock) {
                self.frameOutputBlock(frame);
            }
        }
    }
}

- (void)removeVideoFrameSet {
    // ------------------ frameSet ------------------
    pthread_mutex_lock(&mutexVideoFrame);
    
    std::set<FrameInfo *>::iterator videoItem = videoFrameSet.begin();
    while (videoItem != videoFrameSet.end()) {
        FrameInfo *frameInfo = *videoItem;
        delete []frameInfo->pBuf;
        delete frameInfo;
        
        videoItem++;   // 很关键, 主动前移指针
    }
    videoFrameSet.clear();
    
    pthread_mutex_unlock(&mutexVideoFrame);
}

- (void)removeAudioFrameSet {
    pthread_mutex_lock(&mutexAudioFrame);
    
    std::set<FrameInfo *>::iterator it = audioFrameSet.begin();
    while (it != audioFrameSet.end()) {
        FrameInfo *frameInfo = *it;
        delete []frameInfo->pBuf;
        delete frameInfo;
        
        it++;   // 很关键, 主动前移指针
    }
    audioFrameSet.clear();
    
    pthread_mutex_unlock(&mutexAudioFrame);
}

- (void) removeRecordFrameSet {
    // ------------------ recordVideoFrameSet ------------------
    pthread_mutex_lock(&mutexRecordVideoFrame);
    std::set<FrameInfo *>::iterator videoItem = recordVideoFrameSet.begin();
    while (videoItem != recordVideoFrameSet.end()) {
        FrameInfo *frameInfo = *videoItem;
        delete []frameInfo->pBuf;
        delete frameInfo;
        videoItem++;
    }
    recordVideoFrameSet.clear();
    pthread_mutex_unlock(&mutexRecordVideoFrame);
    
    // ------------------ recordAudioFrameSet ------------------
    pthread_mutex_lock(&mutexRecordAudioFrame);
    std::set<FrameInfo *>::iterator audioItem = recordAudioFrameSet.begin();
    while (audioItem != recordAudioFrameSet.end()) {
        FrameInfo *frameInfo = *audioItem;
        delete []frameInfo->pBuf;
        delete frameInfo;
        audioItem++;
    }
    recordAudioFrameSet.clear();
    pthread_mutex_unlock(&mutexRecordAudioFrame);
}

#pragma mark - 录像

/**
 注册av_read_frame的回调函数
 
 @param opaque URLContext结构体
 @param buf buf
 @param buf_size buf_size
 @return 0
 */
int read_video_packet(void *opaque, uint8_t *buf, int buf_size) {
    pthread_mutex_lock(&mutexRecordVideoFrame);
    
    int count = (int) recordVideoFrameSet.size();
    if (count == 0) {
        pthread_mutex_unlock(&mutexRecordVideoFrame);
        return 0;
    }
    
    FrameInfo *frame = *(recordVideoFrameSet.begin());
    recordVideoFrameSet.erase(recordVideoFrameSet.begin());
    
    pthread_mutex_unlock(&mutexRecordVideoFrame);
    
    int frameLen = frame->frameLen;
    memcpy(buf, frame->pBuf, frameLen);
    
    delete []frame->pBuf;
    delete frame;
    
    return frameLen;
}

/**
 注册av_read_frame的回调函数
 
 @param opaque URLContext结构体
 @param buf buf
 @param buf_size buf_size
 @return 0
 */
int read_audio_packet(void *opaque, uint8_t *buf, int buf_size) {
    pthread_mutex_lock(&mutexRecordAudioFrame);
    
    int count = (int) recordAudioFrameSet.size();
    if (count == 0) {
        pthread_mutex_unlock(&mutexRecordAudioFrame);
        return 0;
    }
    
    FrameInfo *frame = *(recordAudioFrameSet.begin());
    recordAudioFrameSet.erase(recordAudioFrameSet.begin());
    
    pthread_mutex_unlock(&mutexRecordAudioFrame);
    
    int frameLen = frame->frameLen;
    memcpy(buf, frame->pBuf, frameLen);
    
    delete []frame->pBuf;
    delete frame;
    
    return frameLen;
}

#pragma mark - private method

// 获得媒体类型
- (void)recvMediaInfo:(EASY_MEDIA_INFO_T *)info {
    _mediaInfo = *info;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.fetchMediaInfoSuccessBlock) {
            self.fetchMediaInfoSuccessBlock();
        }
    });
}

- (void)pushFrame:(char *)pBuf frameInfo:(EASY_FRAME_INFO *)info type:(int)type {
    if (!_running || pBuf == NULL || info->length == 0) {
        return;
    }
    
    FrameInfo *frameInfo = (FrameInfo *)malloc(sizeof(FrameInfo));
    frameInfo->type = type;
    frameInfo->frameLen = info->length;
    frameInfo->pBuf = new unsigned char[info->length];
    frameInfo->width = info->width;
    frameInfo->height = info->height;
    // 毫秒为单位(1秒=1000毫秒 1秒=1000000微秒)
    frameInfo->timeStamp = info->timestamp_sec * 1000 + info->timestamp_usec / 1000.0;
    
    memcpy(frameInfo->pBuf, pBuf, info->length);
    
    // 根据时间戳排序
    if (type == EASY_SDK_AUDIO_FRAME_FLAG) {
        pthread_mutex_lock(&mutexAudioFrame);    // 加锁
        audioFrameSet.insert(frameInfo);
        pthread_mutex_unlock(&mutexAudioFrame);  // 解锁
    } else {
        pthread_mutex_lock(&mutexVideoFrame);    // 加锁
        videoFrameSet.insert(frameInfo);
        pthread_mutex_unlock(&mutexVideoFrame);  // 解锁
    }
    
    // 录像：保存视频的内容
    if (_recordFilePath) {
        
        if (isKeyFrame == 0) {
            if (info->type == EASY_SDK_VIDEO_FRAME_I) {// 视频帧类型
                isKeyFrame = 1;
                
                dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC));
                dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, NULL);
                dispatch_after(time, queue, ^{
                    // 开始录像
                    *stopRecord = 0;
                    muxer([_recordFilePath UTF8String], stopRecord, read_video_packet, read_audio_packet);
                });
            }
        }
        
        if (isKeyFrame == 1) {
            FrameInfo *frame = (FrameInfo *)malloc(sizeof(FrameInfo));
            frame->type = type;
            frame->frameLen = info->length;
            frame->pBuf = new unsigned char[info->length];
            frame->width = info->width;
            frame->height = info->height;
            frame->timeStamp = info->timestamp_sec * 1000 + info->timestamp_usec / 1000.0;
            
            memcpy(frame->pBuf, pBuf, info->length);
            
            if (type == EASY_SDK_AUDIO_FRAME_FLAG) {
                pthread_mutex_lock(&mutexRecordAudioFrame);    // 加锁
                recordAudioFrameSet.insert(frame);// 根据时间戳排序
                pthread_mutex_unlock(&mutexRecordAudioFrame);  // 解锁
            }
            
            if (type == EASY_SDK_VIDEO_FRAME_FLAG &&    // EASY_SDK_VIDEO_FRAME_FLAG视频帧标志
                info->codec == EASY_SDK_VIDEO_CODEC_H264) { // H264视频编码
                pthread_mutex_lock(&mutexRecordVideoFrame);    // 加锁
                recordVideoFrameSet.insert(frame);// 根据时间戳排序
                pthread_mutex_unlock(&mutexRecordVideoFrame);  // 解锁
            }
        }
    }
}

#pragma mark - HWVideoDecoderDelegate

-(void) getDecodePictureData:(KxVideoFrame *)frame {
    afterDecoderTimeStamp = [[NSDate date] timeIntervalSince1970] * 1000;
    
    if (self.frameOutputBlock) {
        self.frameOutputBlock(frame);
    }
}

-(void) getDecodePixelData:(CVImageBufferRef)frame {
    NSLog(@"--> %@", frame);
}

#pragma mark - dealloc

- (void)dealloc {
    [self removeVideoFrameSet];
    [self removeAudioFrameSet];
    [self removeRecordFrameSet];
    
    // 注销互斥锁
    pthread_mutex_destroy(&mutexVideoFrame);
    pthread_mutex_destroy(&mutexAudioFrame);
    pthread_mutex_destroy(&mutexChan);
    pthread_mutex_destroy(&mutexRecordVideoFrame);
    pthread_mutex_destroy(&mutexRecordAudioFrame);
    
    if (rtspHandle != NULL) {
        /* 释放RTSPClient 参数为RTSPClient句柄 */
        EasyRTMPClient_Release(&rtspHandle);
        rtspHandle = NULL;
    }
}

#pragma mark - getter/setter

- (EASY_MEDIA_INFO_T)mediaInfo {
    return _mediaInfo;
}

// 设置录像的路径
- (void) setRecordFilePath:(NSString *)recordFilePath {
    if ((_recordFilePath) && (!recordFilePath)) {
        _recordFilePath = recordFilePath;
        
        *stopRecord = 1;
        muxer(NULL, stopRecord, read_video_packet, read_audio_packet);
        isKeyFrame = 0;
    }
    
    _recordFilePath = recordFilePath;
}

@end
