//
//  MuxerToVideo.c
//  EasyPlayer
//
//  Created by leo on 2017/12/22.
//  Copyright © 2017年 cs. All rights reserved.
//

#include "MuxerToVideo.h"
#include "libswresample/swresample.h"
#include "EasyTypes.h"
#include "g711.h"

#pragma mark - 文件的操作

AVOutputFormat *ofmt = NULL;
AVFormatContext *ofmt_ctx = NULL;

int result = -1;

AVCodec *videoCodec;
AVCodecContext *videoCodecCtx;

AVCodec *audioCodec;
AVCodecContext *audioCodecCtx;

/**
 关闭文件

 @return 0:成功
 */
int closeOutPut() {
    if (ofmt_ctx) {
        // av_write_trailer()：写入文件尾 Write file trailer
        av_write_trailer(ofmt_ctx);
        
        // close output
        if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE)) {
            avio_close(ofmt_ctx->pb);
        }
        
        avformat_free_context(ofmt_ctx);
        ofmt_ctx = NULL;
    }
    
    return 0;
}

/**
 打开输入文件
 
 @param out_filename 路径
 @return 2:已经打开；1:打开成功;0:打开失败
 */
int openOutPut(const char *out_filename) {
    av_register_all();
    
    // 1、初始化一个用于输出的AVFormatContext结构体
    if (ofmt_ctx == NULL) {
        avformat_alloc_output_context2(&ofmt_ctx, NULL, NULL, out_filename);
        if (ofmt_ctx == NULL) {
            printf("Could not create output context\n");
            return closeOutPut();
        }
        ofmt = ofmt_ctx->oformat;
    }
    
    // 2、在 ofmt_ctx 中创建 Video Stream 通道
    if (videoCodec != NULL && videoCodecCtx != NULL) {
        AVStream *video_out_stream = avformat_new_stream(ofmt_ctx, videoCodec);
        if (avcodec_parameters_from_context(video_out_stream->codecpar, videoCodecCtx) < 0) {
            printf( "Failed to copy context from input to output stream codec context\n");
            return closeOutPut();
        }
        if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER) {
            videoCodecCtx->flags |= CODEC_FLAG_GLOBAL_HEADER;
        }
    }
    
    // 3、在 ofmt_ctx 中创建 Audio Stream 通道
    if (audioCodec != NULL && audioCodec == 0) {
        AVStream *audio_out_stream = avformat_new_stream(ofmt_ctx, audioCodec);
        if (avcodec_parameters_from_context(audio_out_stream->codecpar, audioCodecCtx) < 0) {
            printf( "Failed to copy context from input to output stream codec context\n");
            return closeOutPut();
        }
        if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER) {
            audioCodecCtx->flags |= CODEC_FLAG_GLOBAL_HEADER;
        }
        
        printf("==========Output Information==========\n");
        av_dump_format(ofmt_ctx, 0, out_filename, 1);
        printf("======================================\n");
    }
    
    // avio_open 打开输出文件
    if (!(ofmt->flags & AVFMT_NOFILE)) {
        if (avio_open(&ofmt_ctx->pb, out_filename, AVIO_FLAG_WRITE) < 0) {
            printf("Could not open output file '%s'", out_filename);
            
            return closeOutPut();
        }
    }
    
    // 写入文件头 Write file header
    if (avformat_write_header(ofmt_ctx, NULL) < 0) {
        printf("Error occurred when opening output file\n");
        
        return closeOutPut();
    }
    
    return 2;
}

// avpacket写入文件
int writeData(const char *out_filename, AVPacket pkt, AVCodecContext *pCodecCtx) {
    if (out_filename == NULL) {
        return closeOutPut();
    } else {
        if (videoCodec == NULL || videoCodecCtx == NULL ||
            audioCodec == NULL || audioCodecCtx == NULL) {
            return 0;
        }
        
        if (ofmt_ctx == NULL) {
            openOutPut(out_filename);
        }
        
        //Convert PTS/DTS
        pkt.pts = av_rescale_q_rnd(pkt.pts, pCodecCtx->time_base, pCodecCtx->time_base, (AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX));
        pkt.dts = av_rescale_q_rnd(pkt.dts, pCodecCtx->time_base, pCodecCtx->time_base, (AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX));
        pkt.duration = 0;// av_rescale_q(pkt.duration, pCodecCtx->time_base, pCodecCtx->time_base);
        pkt.pos = -1;
        
        printf("Write 1 Packet. size:%5d\tpts:%lld\n", pkt.size, pkt.pts);
        
        // av_interleaved_write_frame()：写入一个AVPacket到输出文件
        if (av_interleaved_write_frame(ofmt_ctx, &pkt) < 0) {
            printf("Error muxing packet\n");
        }
        
        av_packet_unref(&pkt);
        
        return 1;
    }
}

#pragma mark - 转换为AVPacket

// 将h264流转换为AVPacket
int convertVideoToAVPacket(const char *out_filename, void *recordHandle, Muxer_Video_PARAM *pDecodeParam) {
    Muxer_Video_COMPONENT *pComponent = (Muxer_Video_COMPONENT *)recordHandle;
    if (pComponent == NULL || pComponent->pCodecCtx == NULL || pComponent->pFrame == NULL) {
        return 0;
    }
    
    videoCodec = pComponent->avCodec;
    videoCodecCtx = pComponent->pCodecCtx;
    
    AVPacket packet;
    av_init_packet(&packet);
    if (pDecodeParam->need_sps_head) {
        memset(pComponent->pNewStream+pComponent->newStreamLen, 0, 1024*1024-pComponent->newStreamLen);
        pComponent->pNewStream[pComponent->newStreamLen+0] = 0;
        pComponent->pNewStream[pComponent->newStreamLen+1] = 0;
        pComponent->pNewStream[pComponent->newStreamLen+2] = 1;
        memcpy(pComponent->pNewStream+3+pComponent->newStreamLen, pDecodeParam->pStream, pDecodeParam->nLen);
        pComponent->newStreamLen += pDecodeParam->nLen +3;
        
        packet.size = pComponent->newStreamLen;
        packet.data = pComponent->pNewStream;
    } else {
        packet.size = pDecodeParam->nLen;
        packet.data = pDecodeParam->pStream;
    }
    
    packet.stream_index = 0;
    
    if (videoCodecCtx) {
        writeData(out_filename, packet, videoCodecCtx);
    }
    
    return 0;
}

// 将aac流转换为AVPacket
int convertAudioToAVPacket(const char *out_filename, void *audioDecHandle, unsigned char *pData, int nLen) {
    Muxer_Audio_Handle *pComponent = (Muxer_Audio_Handle *)audioDecHandle;

    Muxer_Audio_PARAM *aacFFmpeg = (Muxer_Audio_PARAM *)pComponent->pContext;
    if (aacFFmpeg != NULL) {
        audioCodec = aacFFmpeg->avCodec;
        audioCodecCtx = aacFFmpeg->pCodecCtx;
    } else {
        audioCodec = 0;
        audioCodecCtx = 0;
    }
    
    AVPacket packet;
    av_init_packet(&packet);
    
    packet.size = nLen;
    packet.data = pData;
    packet.stream_index = 0;
    
    if (audioCodecCtx) {
        writeData(out_filename, packet, audioCodecCtx);
    }
    
    return 0;
}

#pragma mark - 创建视频handle

static Muxer_Video_METHODE s_uiDecodeMethod = Muxer_Video_IDM_SW;

unsigned char Muxer_H264_SPS_PPS_NEW[] = {
    48,   0,   0,   0,
    9,   0,   0,   0, 103,  88,   0,  21, 150,  86,  11,   4, 162,   9,   0,   0,   0,
    103,  88,   0,  21,  69, 149, 133, 137, 136,  10,   0,   0,   0, 103,  88,   0,  21,
    101, 149, 129,  96,  36, 136,   9,   0,   0,   0, 103,  88,   0,  21,  33, 101,  97,
    71, 136,  10,   0,   0,   0, 103,  88,   0,  21,  41, 101,  96, 176, 248, 128,  10,
    0,   0,   0, 103,  88,   0,  21,  49, 101,  96, 160, 248, 128,  10,   0,   0,   0,
    103,  88,   0,  21,  57, 101,  96,  80,  30, 136,  10,   0,   0,   0, 103,  88,   0,
    21,  16,  89,  88,  20,  15, 136,  10,   0,   0,   0, 103,  88,   0,  21,  18,  89,
    88,  20,   4, 162,  10,   0,   0,   0, 103,  88,   0,  21,  20,  89,  88,  22,   7,
    162,  10,   0,   0,   0, 103,  88,   0,  21,  22,  89,  88,  22,  15, 136,  10,   0,
    0,   0, 103,  88,   0,  21,  24,  89,  88,  22,   4, 162,  11,   0,   0,   0, 103,
    88,   0,  21,  26,  89,  88,  22, 130,  72, 128,  10,   0,   0,   0, 103,  88,   0,
    21,  28,  89,  88,  22, 135, 162,  10,   0,   0,   0, 103,  88,   0,  21,  30,  89,
    88,  22, 143, 136,  11,   0,   0,   0, 103,  88,   0,  21,   8,  22,  86,   5, 161,
    40, 128,   4,   0,   0,   0, 104, 206,  56, 128,   4,   0,   0,   0, 104,  83, 143,
    32,   4,   0,   0,   0, 104, 104, 227, 136,   4,   0,   0,   0, 104,  34,  56, 242,
    4,   0,   0,   0, 104,  43,  56, 226,   4,   0,   0,   0, 104,  51,  56, 242,   5,
    0,   0,   0, 104,  57,  14,  56, 128,   5,   0,   0,   0, 104,  16,  67, 143,  32,
    5,   0,   0,   0, 104,  18,  83, 142,  32,   5,   0,   0,   0, 104,  20,  83, 143,
    32,   5,   0,   0,   0, 104,  22,  99, 142,  32,   5,   0,   0,   0, 104,  24,  99,
    143,  32,   5,   0,   0,   0, 104,  26, 115, 142,  32,   5,   0,   0,   0, 104,  28,
    115, 143,  32,   5,   0,   0,   0, 104,  30,  32, 227, 136,   5,   0,   0,   0, 104,
    8,   8,  56, 242,   5,   0,   0,   0, 104,   8, 137,  56, 226,   5,   0,   0,   0,
    104,   9,   9,  56, 242,   5,   0,   0,   0, 104,   9, 138,  56, 226,   5,   0,   0,
    0, 104,  10,  10,  56, 242,   5,   0,   0,   0, 104,  10, 139,  56, 226,   5,   0,
    0,   0, 104,  11,  11,  56, 242,   5,   0,   0,   0, 104,  11, 140,  56, 226,   5,
    0,   0,   0, 104,  12,  12,  56, 242,   5,   0,   0,   0, 104,  12, 141,  56, 226,
    5,   0,   0,   0, 104,  13,  13,  56, 242,   5,   0,   0,   0, 104,  13, 142,  56,
    226,   5,   0,   0,   0, 104,  14,  14,  56, 242,   5,   0,   0,   0, 104,  14, 143,
    56, 226,   5,   0,   0,   0, 104,  15,  15,  56, 242,   6,   0,   0,   0, 104,  15,
    132,  14,  56, 128,   6,   0,   0,   0, 104,   4,   1,   3, 143,  32
};

void *muxer_Video_COMPONENT_Create(Muxer_Video_CREATE_PARAM *pCreateParam) {
    Muxer_Video_COMPONENT *pComponent = (Muxer_Video_COMPONENT *)malloc(sizeof(Muxer_Video_COMPONENT));
    pComponent->avCodec = NULL;
    pComponent->pCodecCtx = NULL;
    pComponent->pFrame = NULL;
    pComponent->pImgConvertCtx = NULL;
    
    s_uiDecodeMethod = pCreateParam->method;
    
    // [5]、avcodec_find_decoder()查找解码器
    AVCodec *pCodec = avcodec_find_decoder(AV_CODEC_ID_H264);
    if (pCodec == NULL) {
        printf("avcodec_find_decoder codec error\r\n");
        return 0;
    }
    
    pComponent->avCodec = pCodec;
    
    // 创建显示contedxt
    pComponent->pCodecCtx = avcodec_alloc_context3(pCodec);
    pComponent->pCodecCtx->width = pCreateParam->nMaxImgWidth;
    pComponent->pCodecCtx->height = pCreateParam->nMaxImgHeight;
    pComponent->pCodecCtx->pix_fmt = AV_PIX_FMT_YUV420P;
    
    // [6]、如果找到了解码器，则打开解码器
    AVDictionary *options = NULL;
    if(avcodec_open2(pComponent->pCodecCtx, pCodec, &options) < 0) {
        printf("open codec error\r\n");
        return 0;
    }
    
    // [7]、打开解码器之后用av_frame_alloc为解码帧分配内存
    pComponent->pFrame = av_frame_alloc();
    if (pComponent->pFrame == NULL) {
        return 0;
    }
    
    pComponent->pNewStream = (unsigned char *)malloc(1024 * 1024);
    memset(pComponent->pNewStream , 0, 1024 * 1024);
    
    // add sps pps head
    unsigned char *p1, *ps;
    int * ptmplen;
    int k, m, n;
    int spsppslen = 0;
    p1 = Muxer_H264_SPS_PPS_NEW;
    ptmplen = (int *)p1;
    m = *ptmplen;
    ps = pComponent->pNewStream;
    
    p1 += 4;
    for (k = 0; k < m; k++) {
        memcpy(&n, p1, 4);
        
        ps[0] = 0;
        ps[1] = 0;
        ps[2] = 1;
        memcpy(ps + 3, p1 + 4, n);
        ps += 3 + n;
        spsppslen += (3 + n);
        
        p1 += (4 + n);
    }
    
    pComponent->newStreamLen = spsppslen;
    pComponent->uiOriginLen = pComponent->newStreamLen;
    pComponent->bScaleCreated = 0;
    
    return (void *)pComponent;
}

#pragma mark - 创建音频handle

void *muxer_Audio_PARAM_Create(enum AVCodecID codecid,  // 解码器ID
                         int sample_rate,               // 采样率(44.1kHZ)
                         int channels,                  // 声道数(2)
                         int bit_rate) {                // 码率( = 采样位数(bit) × 采样频率(HZ) × 声道数)
    Muxer_Audio_PARAM *pComponent = (Muxer_Audio_PARAM *)malloc(sizeof(Muxer_Audio_PARAM));
    
    // [5]、avcodec_find_decoder()查找解码器
    AVCodec *pCodec = avcodec_find_decoder(codecid);//AV_CODEC_ID_AAC
    if (pCodec == NULL) {
        printf("find %d decoder error", codecid);
        return 0;
    }
    
    printf("aac_decoder_create codecid=%d\n", codecid);
    
    pComponent->avCodec = pCodec;
    
    // 创建显示contedxt
    pComponent->pCodecCtx = avcodec_alloc_context3(pCodec);
    pComponent->pCodecCtx->channels = channels;
    pComponent->pCodecCtx->sample_rate = sample_rate;
    pComponent->pCodecCtx->bit_rate = bit_rate;
    
    // 码率 = 采样位数(bit) × 采样频率(HZ) × 声道数    采样位数?  有问题
    pComponent->pCodecCtx->bits_per_coded_sample = 2;
    
    printf("bits_per_coded_sample:%d\r\n",pComponent->pCodecCtx->bits_per_coded_sample);
    
    // [6]、如果找到了解码器，则打开解码器
    if(avcodec_open2(pComponent->pCodecCtx, pCodec, NULL) < 0) {
        printf("open codec error\r\n");
        return 0;
    }
    
    // [7]、打开解码器之后用av_frame_alloc为解码帧分配内存
    pComponent->pFrame = av_frame_alloc();
    
    pComponent->au_convert_ctx = swr_alloc_set_opts(NULL,
                                                    pComponent->pCodecCtx->channel_layout,  // out_ch_layout
                                                    AV_SAMPLE_FMT_S16,                      // out_sample_fmt 在编码前，我希望的采样格式
                                                    pComponent->pCodecCtx->sample_rate,     // out_sample_rate
                                                    pComponent->pCodecCtx->channel_layout,  // in_ch_layout
                                                    pComponent->pCodecCtx->sample_fmt,      // in_sample_fmt PCM源文件的采样格式
                                                    pComponent->pCodecCtx->sample_rate,     // in_sample_rate
                                                    0,                                      // log_offset
                                                    NULL);                                  // log_ctx
    // 初始化SwrContext
    swr_init(pComponent->au_convert_ctx);
    printf("aac_decoder_create end");
    
    return (void *)pComponent;
}

Muxer_Audio_Handle* muxer_Audio_Handle_Create(int code, int sample_rate, int channels, int sample_bit) {
    Muxer_Audio_Handle *pHandle = malloc(sizeof(Muxer_Audio_Handle));
    pHandle->code = code;
    pHandle->pContext = 0;
    if (code == EASY_SDK_AUDIO_CODEC_AAC || code == EASY_SDK_AUDIO_CODEC_G726) {
        pHandle->pContext = muxer_Audio_PARAM_Create(code, sample_rate, channels, sample_bit);
        if(NULL == pHandle->pContext) {
            free(pHandle);
            return NULL;
        }
    }
    
    return pHandle;
}
