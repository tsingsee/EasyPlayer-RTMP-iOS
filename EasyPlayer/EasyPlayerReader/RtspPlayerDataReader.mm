
#import "RtspPlayerDataReader.h"

#include <pthread.h>
#include <vector>
#include <set>
#include <string.h>
#include <math.h>

#import "HWVideoDecoder.h"
#include "VideoDecode.h"
#include "EasyAudioDecoder.h"

#include "Muxer.h"

struct RtspFrameInfo {
    RtspFrameInfo() : pBuf(NULL), frameLen(0), type(0), timeStamp(0), width(0), height(0){}
    
    unsigned char *pBuf;
    int frameLen;
    int type;
    CGFloat timeStamp;// 毫秒为单位(1秒=1000毫秒 1秒=1000000微秒)
    int width;
    int height;
};

class RtspCompare {
public:
    bool operator ()(RtspFrameInfo *lhs, RtspFrameInfo *rhs) const {
        return lhs->timeStamp < rhs->timeStamp;
    }
};

pthread_mutex_t mutexRecordRtspVideoFrame;
pthread_mutex_t mutexRecordRtspAudioFrame;

std::multiset<RtspFrameInfo *, RtspCompare> recordRtspVideoFrameSet;
std::multiset<RtspFrameInfo *, RtspCompare> recordRtspAudioFrameSet;

int isRtspKeyFrame = 0; // 是否到了I帧
int *stopRtspRecord = (int *)malloc(sizeof(int));// 停止录像

@interface RtspPlayerDataReader()<HWVideoDecoderDelegate> {
    // RTSP拉流句柄
    Easy_Handle rtspHandle;
    
    // 互斥锁
    pthread_mutex_t mutexVideoFrame;
    pthread_mutex_t mutexAudioFrame;
    
    pthread_mutex_t mutexCloseAudio;
    pthread_mutex_t mutexCloseVideo;
    
    pthread_mutex_t mutexInit;
    pthread_mutex_t mutexStop;
    
    void *_videoDecHandle;  // 视频解码句柄
    void *_audioDecHandle;  // 音频解码句柄
    
    EASY_MEDIA_INFO_T _mediaInfo;   // 媒体信息
    
    std::multiset<RtspFrameInfo *, RtspCompare> videoFrameSet;
    std::multiset<RtspFrameInfo *, RtspCompare> audioFrameSet;
    
    CGFloat lastFrameTimeStamp;
    CGFloat mNewestStample;
    NSTimeInterval beforeDecoderTimeStamp;
    NSTimeInterval afterDecoderTimeStamp;
    
    CGFloat _lastVideoFramePosition;
    
    // 视频硬解码器
    HWVideoDecoder *_hwDec;
}

@property (nonatomic, readwrite) BOOL running;
@property (nonatomic, strong) NSThread *videoThread;
@property (nonatomic, strong) NSThread *audioThread;

@property (nonatomic, assign) int lastWidth;
@property (nonatomic, assign) int lastHeight;

// EASY_SDK_VIDEO_CODEC_H265/EASY_SDK_VIDEO_CODEC_H264编码方式
@property (nonatomic) enum AVCodecID codecID;

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
    
    RtspPlayerDataReader *reader = (__bridge RtspPlayerDataReader *)channelPtr;
    
    if (frameInfo != NULL) {
        if (frameType == EASY_SDK_AUDIO_FRAME_FLAG) {// EASY_SDK_AUDIO_FRAME_FLAG音频帧标志
            [reader pushFrame:pBuf frameInfo:frameInfo type:frameType];
        } else if (frameType == EASY_SDK_VIDEO_FRAME_FLAG ) {   // EASY_SDK_VIDEO_FRAME_FLAG视频帧标志
            [reader pushFrame:pBuf frameInfo:frameInfo type:frameType];
            
            if (frameInfo->codec == EASY_SDK_VIDEO_CODEC_H265) {// H265视频编码
                reader.codecID = AV_CODEC_ID_HEVC;
            } else if (frameInfo->codec == EASY_SDK_VIDEO_CODEC_H264) {// H264视频编码
                reader.codecID = AV_CODEC_ID_H264;
            }
        }
    } else {
        if (frameType == EASY_SDK_MEDIA_INFO_FLAG) {// EASY_SDK_MEDIA_INFO_FLAG媒体类型标志
            EASY_MEDIA_INFO_T mediaInfo = *((EASY_MEDIA_INFO_T *)pBuf);
            
            NSLog(@"\n Media Info:video:%u fps:%u audio:%u channel:%u sampleRate:%u \n",
                  mediaInfo.u32VideoCodec,
                  mediaInfo.u32VideoFps,
                  mediaInfo.u32AudioCodec,
                  mediaInfo.u32AudioChannel,
                  mediaInfo.u32AudioSamplerate);
            
            if (mediaInfo.u32AudioChannel <= 0 || mediaInfo.u32AudioChannel > 2) {
                mediaInfo.u32AudioChannel = 1;
            }
            
            [reader recvMediaInfo:&mediaInfo];
        }
    }
    
    return 0;
}

@implementation RtspPlayerDataReader

+ (void)startUp {
    DecodeRegiestAll();
}

#pragma mark - init

- (id)initWithUrl:(NSString *)url {
    if (self = [super init]) {
        // 动态方式是采用pthread_mutex_init()函数来初始化互斥锁
        pthread_mutex_init(&mutexVideoFrame, 0);
        pthread_mutex_init(&mutexAudioFrame, 0);
        
        pthread_mutex_init(&mutexRecordRtspVideoFrame, 0);
        pthread_mutex_init(&mutexRecordRtspAudioFrame, 0);
        
        pthread_mutex_init(&mutexCloseAudio, 0);
        pthread_mutex_init(&mutexCloseVideo, 0);
        
        pthread_mutex_init(&mutexInit, 0);
        pthread_mutex_init(&mutexStop, 0);
        
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
    
    mNewestStample = 0;
    _lastVideoFramePosition = 0;
    _running = YES;
    
    self.videoThread = [[NSThread alloc] initWithTarget:self selector:@selector(videoThreadFunc) object:nil];
    [self.videoThread start];
    
    self.audioThread = [[NSThread alloc] initWithTarget:self selector:@selector(audioThreadFunc) object:nil];
    [self.audioThread start];
}

- (void)stop {
    pthread_mutex_lock(&mutexStop);
    
    if (!_running) {
        pthread_mutex_unlock(&mutexStop);
        return;
    }
    
    if (rtspHandle != NULL) {
        EasyRTSP_SetCallback(rtspHandle, NULL);
        EasyRTSP_CloseStream(rtspHandle);// 关闭网络流
    }
    
    mNewestStample = 0;
    _running = false;
    [self.videoThread cancel];
    [self.audioThread cancel];
    
    pthread_mutex_unlock(&mutexStop);
}

#pragma mark - dealloc

- (void)dealloc {
    
    [self stop];
    
    [self removeVideoFrameSet];
    [self removeAudioFrameSet];
    [self removeRecordFrameSet];
    
    // 注销互斥锁
    pthread_mutex_destroy(&mutexVideoFrame);
    pthread_mutex_destroy(&mutexAudioFrame);
    pthread_mutex_destroy(&mutexInit);
    pthread_mutex_destroy(&mutexRecordRtspVideoFrame);
    pthread_mutex_destroy(&mutexRecordRtspAudioFrame);
    
    pthread_mutex_destroy(&mutexCloseVideo);
    pthread_mutex_destroy(&mutexCloseAudio);
    pthread_mutex_destroy(&mutexStop);
}

#pragma mark - 子线程方法

- (void) initRtspHandle {
    // ------------ 加锁mutexInit ------------
    pthread_mutex_lock(&mutexInit);
    if (rtspHandle == NULL) {
        int ret = EasyRTSP_Init(&rtspHandle);
        if (ret != 0) {
            NSLog(@"EasyRTSP_Init err %d", ret);
        } else {
            /* 设置数据回调 */
            EasyRTSP_SetCallback(rtspHandle, RTSPDataCallBack);
            
            /* 打开网络流 */
            ret = EasyRTSP_OpenStream(rtspHandle,
                                      1,
                                      (char *)[self.url UTF8String],
                                      self.transportMode,
                                      EASY_SDK_VIDEO_FRAME_FLAG | EASY_SDK_AUDIO_FRAME_FLAG,// 视频帧标|音频帧标志
                                      0,
                                      0,
                                      (__bridge void *)self,
                                      1000,     // 1000表示长连接,即如果网络断开自动重连, 其它值为连接次数
                                      0,        // 默认为0,即回调输出完整的帧, 如果为1,则输出RTP包
                                      self.sendOption,// 0x00:不发送心跳 0x01:OPTIONS 0x02:GET_PARAMETER
                                      3);       // 日志打印输出等级，0表示不输出
            NSLog(@"EasyRTSP_OpenStream ret = %d", ret);
        }
    }
    pthread_mutex_unlock(&mutexInit);
    // ------------ 解锁mutexInit ------------
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
        
        RtspFrameInfo *frame = *(audioFrameSet.begin());
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
    
    pthread_mutex_lock(&mutexCloseAudio);
    if (_audioDecHandle != NULL) {
        EasyAudioDecodeClose((EasyAudioHandle *)_audioDecHandle);
        _audioDecHandle = NULL;
    }
    pthread_mutex_unlock(&mutexCloseAudio);
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
        
        RtspFrameInfo *frame = *(videoFrameSet.begin());
        videoFrameSet.erase(videoFrameSet.begin());// erase()函数的功能是用来删除容器中的元素
        
        beforeDecoderTimeStamp = [[NSDate date] timeIntervalSince1970] * 1000;// 毫秒数
        
        pthread_mutex_unlock(&mutexVideoFrame);
        // ------------ 解锁mutexVideoFrame ------------
        
        // 视频的分辨率改变了，则需要重新初始化解码器
        BOOL isInit = NO;
        if (frame->type == EASY_SDK_VIDEO_FRAME_I && (self.lastWidth != frame->width || self.lastHeight != frame->height)) {// 视频帧类型
            isInit = YES;
            
            self.lastWidth = frame->width;
            self.lastHeight = frame->height;
        }
        
        if (self.useHWDecoder) {
            [_hwDec decodeVideoData:frame->pBuf len:frame->frameLen isInit:isInit];
        } else {
            [self decodeVideoFrame:frame isInit:isInit];
        }
        
        delete []frame->pBuf;
        
        // 帧里面有个timestamp 是当前帧的时间戳， 先获取下系统时间A，然后解码播放，解码后获取系统时间B， B-A就是本次的耗时。sleep的时长就是 当期帧的timestamp  减去 上一个视频帧的timestamp 再减去 这次的耗时
        afterDecoderTimeStamp = [[NSDate date] timeIntervalSince1970] * 1000;
        if (lastFrameTimeStamp != 0) {
            float sleepTime = (frame->timeStamp - lastFrameTimeStamp - (afterDecoderTimeStamp - beforeDecoderTimeStamp)) * 1000;
            if (sleepTime > 100000) {
                NSLog(@"sleep time.too long:%f", sleepTime);
                sleepTime = 100000;
            }
            
            if (sleepTime > 0) {
                // 设置缓存的时间戳
                float cache = (mNewestStample - frame->timeStamp) * 1000;
                float newDelay = 0;
                
                if (self.useHWDecoder) {
                    newDelay = [self fixSleepTime:sleepTime totalTimestampDifferUs:cache delayUs:100000];
                } else {
                    newDelay = [self fixSleepTime:sleepTime totalTimestampDifferUs:cache delayUs:50000];
                }
                
                // usleep功能把进程挂起一段时间， 单位是微秒（百万分之一秒）；
                usleep(newDelay);
            }
        }
        
        lastFrameTimeStamp = frame->timeStamp;
        
        delete frame;
    }
    
    [self removeVideoFrameSet];
    
    pthread_mutex_lock(&mutexCloseVideo);
    if (_videoDecHandle != NULL) {
        DecodeClose(_videoDecHandle);
        _videoDecHandle = NULL;
    }
    pthread_mutex_unlock(&mutexCloseVideo);
    
    if (self.useHWDecoder) {
        pthread_mutex_lock(&mutexCloseVideo);
        [_hwDec closeDecoder];
        pthread_mutex_unlock(&mutexCloseVideo);
    }
}

#pragma mark - 解码视频帧

- (void)decodeVideoFrame:(RtspFrameInfo *)video isInit:(BOOL)isInit {
    if (_videoDecHandle == NULL || isInit) {
        DEC_CREATE_PARAM param;
        param.nMaxImgWidth = video->width;
        param.nMaxImgHeight = video->height;
        param.coderID = CODER_H264;
        param.method = IDM_SW;
        param.avCodecID = self.codecID;
        
        _videoDecHandle = DecodeCreate(&param);
    }
    
    if (_videoDecHandle == NULL) {
        return;
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
            if (_lastVideoFramePosition == 0) {
                _lastVideoFramePosition = video->timeStamp;
            }
            
            CGFloat duration = (video->timeStamp - _lastVideoFramePosition - decodeInterval) / 1000.0;
            if (duration >= 1.0 || duration <= -1.0) {
                duration = 0.02;
            }
            
            // 第一种显示方式：KxVideoFrameYUV
            KxVideoFrameYUV *frame = [KxVideoFrameYUV handleVideoFrame:param.pFrame videoCodecCtx:param.pCodecCtx];
            frame.width = param.nOutWidth;
            frame.height = param.nOutHeight;
            frame.position = video->timeStamp / 1000.0;
            frame.duration = duration;
            
//            // 第二种显示方式：KxVideoFrameRGB
//            KxVideoFrameRGB *frame = [[KxVideoFrameRGB alloc] init];
//            frame.width = param.nOutWidth;
//            frame.height = param.nOutHeight;
//            frame.linesize = param.nOutWidth * 3;
//            frame.hasAlpha = NO;
//            frame.rgb = [NSData dataWithBytes:param.pImgRGB length:param.nLineSize * param.nOutHeight];
//            frame.position = video->timeStamp / 1000.0;
//            frame.duration = duration;

            _lastVideoFramePosition = video->timeStamp;
            afterDecoderTimeStamp = [[NSDate date] timeIntervalSince1970] * 1000;
            
            if (self.frameOutputBlock) {
                // 第一种显示方式：KxVideoFrameYUV
                self.frameOutputBlock(frame, (Easy_U32)(frame.luma.length + frame.chromaB.length + frame.chromaR.length));
                
//                // 第二种显示方式：KxVideoFrameRGB
//                self.frameOutputBlock(frame, (Easy_U32)frame.rgb.length);
            }
        }
    }
}

#pragma mark - 解码音频帧

- (void)decodeAudioFrame:(RtspFrameInfo *)audio {
    if (_audioDecHandle == NULL) {
        _audioDecHandle = EasyAudioDecodeCreate(_mediaInfo.u32AudioCodec,
                                                _mediaInfo.u32AudioSamplerate,
                                                _mediaInfo.u32AudioChannel,
                                                16);
    }
    
    if (_audioDecHandle == NULL) {
        return;
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
                self.frameOutputBlock(frame, (Easy_U32)frame.samples.length);
            }
        }
    }
}

- (void)removeVideoFrameSet {
    // ------------------ frameSet ------------------
    pthread_mutex_lock(&mutexVideoFrame);
    
    std::set<RtspFrameInfo *>::iterator videoItem = videoFrameSet.begin();
    while (videoItem != videoFrameSet.end()) {
        RtspFrameInfo *frameInfo = *videoItem;
        delete []frameInfo->pBuf;
        delete frameInfo;
        
        videoItem++;   // 很关键, 主动前移指针
    }
    videoFrameSet.clear();
    
    pthread_mutex_unlock(&mutexVideoFrame);
}

- (void)removeAudioFrameSet {
    pthread_mutex_lock(&mutexAudioFrame);
    
    std::set<RtspFrameInfo *>::iterator it = audioFrameSet.begin();
    while (it != audioFrameSet.end()) {
        RtspFrameInfo *frameInfo = *it;
        delete []frameInfo->pBuf;
        delete frameInfo;
        
        it++;   // 很关键, 主动前移指针
    }
    audioFrameSet.clear();
    
    pthread_mutex_unlock(&mutexAudioFrame);
}

- (void) removeRecordFrameSet {
    // ------------------ recordVideoFrameSet ------------------
    pthread_mutex_lock(&mutexRecordRtspVideoFrame);
    std::set<RtspFrameInfo *>::iterator videoItem = recordRtspVideoFrameSet.begin();
    while (videoItem != recordRtspVideoFrameSet.end()) {
        RtspFrameInfo *frameInfo = *videoItem;
        delete []frameInfo->pBuf;
        delete frameInfo;
        videoItem++;
    }
    recordRtspVideoFrameSet.clear();
    pthread_mutex_unlock(&mutexRecordRtspVideoFrame);
    
    // ------------------ recordRtspAudioFrameSet ------------------
    pthread_mutex_lock(&mutexRecordRtspAudioFrame);
    std::set<RtspFrameInfo *>::iterator audioItem = recordRtspAudioFrameSet.begin();
    while (audioItem != recordRtspAudioFrameSet.end()) {
        RtspFrameInfo *frameInfo = *audioItem;
        delete []frameInfo->pBuf;
        delete frameInfo;
        audioItem++;
    }
    recordRtspAudioFrameSet.clear();
    pthread_mutex_unlock(&mutexRecordRtspAudioFrame);
}

#pragma mark - 录像

/**
 注册av_read_frame的回调函数
 
 @param opaque URLContext结构体
 @param buf buf
 @param buf_size buf_size
 @return 0
 */
int read_rtsp_video_packet(void *opaque, uint8_t *buf, int buf_size) {
    pthread_mutex_lock(&mutexRecordRtspVideoFrame);
    
    int count = (int) recordRtspVideoFrameSet.size();
    if (count == 0) {
        pthread_mutex_unlock(&mutexRecordRtspVideoFrame);
        return 0;
    }
    
    RtspFrameInfo *frame = *(recordRtspVideoFrameSet.begin());
    recordRtspVideoFrameSet.erase(recordRtspVideoFrameSet.begin());
    
    pthread_mutex_unlock(&mutexRecordRtspVideoFrame);
    
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
int read_rtsp_audio_packet(void *opaque, uint8_t *buf, int buf_size) {
    pthread_mutex_lock(&mutexRecordRtspAudioFrame);
    
    int count = (int) recordRtspAudioFrameSet.size();
    if (count == 0) {
        pthread_mutex_unlock(&mutexRecordRtspAudioFrame);
        return 0;
    }
    
    RtspFrameInfo *frame = *(recordRtspAudioFrameSet.begin());
    recordRtspAudioFrameSet.erase(recordRtspAudioFrameSet.begin());
    
    pthread_mutex_unlock(&mutexRecordRtspAudioFrame);
    
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
    
    RtspFrameInfo *frameInfo = (RtspFrameInfo *)malloc(sizeof(RtspFrameInfo));
    frameInfo->type = type;
    frameInfo->frameLen = info->length;
    frameInfo->pBuf = new unsigned char[info->length];
    frameInfo->width = info->width;
    frameInfo->height = info->height;
    // 毫秒为单位(1秒=1000毫秒 1秒=1000000微秒)
    frameInfo->timeStamp = info->timestamp_sec * 1000 + info->timestamp_usec / 1000.0;
    mNewestStample = frameInfo->timeStamp;
    
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
        
        if (isRtspKeyFrame == 0) {
            if (info->type == EASY_SDK_VIDEO_FRAME_I) {// 视频帧类型
                isRtspKeyFrame = 1;
                
                dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC));
                dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, NULL);
                dispatch_after(time, queue, ^{
                    // 开始录像
                    *stopRtspRecord = 0;
                    muxer([self.recordFilePath UTF8String], stopRtspRecord, read_rtsp_video_packet, read_rtsp_audio_packet);
                });
            }
        }
        
        if (isRtspKeyFrame == 1) {
            RtspFrameInfo *frame = (RtspFrameInfo *)malloc(sizeof(RtspFrameInfo));
            frame->type = type;
            frame->frameLen = info->length;
            frame->pBuf = new unsigned char[info->length];
            frame->width = info->width;
            frame->height = info->height;
            frame->timeStamp = info->timestamp_sec * 1000 + info->timestamp_usec / 1000.0;
            
            memcpy(frame->pBuf, pBuf, info->length);
            
            if (type == EASY_SDK_AUDIO_FRAME_FLAG) {
                pthread_mutex_lock(&mutexRecordRtspAudioFrame);    // 加锁
                recordRtspAudioFrameSet.insert(frame);// 根据时间戳排序
                pthread_mutex_unlock(&mutexRecordRtspAudioFrame);  // 解锁
            }
            
            if (type == EASY_SDK_VIDEO_FRAME_FLAG &&    // EASY_SDK_VIDEO_FRAME_FLAG视频帧标志
                info->codec == EASY_SDK_VIDEO_CODEC_H264) { // H264视频编码
                pthread_mutex_lock(&mutexRecordRtspVideoFrame);    // 加锁
                recordRtspVideoFrameSet.insert(frame);// 根据时间戳排序
                pthread_mutex_unlock(&mutexRecordRtspVideoFrame);  // 解锁
            }
        }
    }
}

#pragma mark - HWVideoDecoderDelegate

-(void) getDecodePictureData:(KxVideoFrame *)frame  length:(unsigned int) length {
    afterDecoderTimeStamp = [[NSDate date] timeIntervalSince1970] * 1000;
    
    if (self.frameOutputBlock) {
        self.frameOutputBlock(frame, length);
    }
}

-(void) getDecodePixelData:(CVImageBufferRef)frame {
    NSLog(@"--> %@", frame);
}

#pragma mark - getter/setter

- (EASY_MEDIA_INFO_T)mediaInfo {
    return _mediaInfo;
}

// 设置录像的路径
- (void) setRecordFilePath:(NSString *)recordFilePath {
    if ((_recordFilePath) && (!recordFilePath)) {
        _recordFilePath = recordFilePath;
        
        *stopRtspRecord = 1;
        muxer(NULL, stopRtspRecord, read_rtsp_video_packet, read_rtsp_audio_packet);
        isRtspKeyFrame = 0;
    }
    
    _recordFilePath = recordFilePath;
}

/**
 该方法主要是播放器上层用于缓存流媒体数据，使播放更加的平滑(https://blog.csdn.net/jinlong0603/article/details/85041569)
 
 @param sleepTimeUs 当前帧时间戳与前一帧时间戳的差值并去除了解码的耗时（单位是微秒）
 @param total 当前中缓存的时间长度（单位是微秒）
 @param delayUs 个人设置的缓存的总大小：
 硬解码，设置的默认缓存为100000微秒，软解码，设置的是50000微秒。
 如果想将延迟降到极限，就调整第三个参数为0，这样即不希望上层缓存数据，尽快的解码上屏显示。
 @return 延迟时间戳
 */
- (float) fixSleepTime:(float)sleepTimeUs totalTimestampDifferUs:(float)total delayUs:(float)delayUs {
    if (total < 0) {
        NSLog(@"totalTimestampDifferUs is:%f, this should not be happen.", total);
        total = 0;
    }
    
    double dValue = ((double) (delayUs - total)) / 1000000;
    double radio = exp(dValue);
    double r = sleepTimeUs * radio + 0.5f;
    
    NSLog(@"===>> %ff, %f, %f->%f微秒", sleepTimeUs, total, delayUs, r);
    
    return (long) r;
}

@end
