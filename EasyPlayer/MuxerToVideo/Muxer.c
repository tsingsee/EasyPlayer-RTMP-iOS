//
//  Muxer.c
//  EasyPlayerRTMP
//
//  Created by liyy on 2018/3/19.
//  Copyright © 2018年 cs. All rights reserved.
//

#include "Muxer.h"
#include <pthread.h>
#include <unistd.h>
#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"

#define BUF_SIZE 1024 * 1024 * 1

// 网络流的参数
AVIOContext *pb = NULL;
AVInputFormat *inFmt = NULL;
AVFormatContext *inFmtCtx = NULL;
AVPacket avPacket;

int frame_index = 0;
int videoindex = -1;
int audioindex = -1;
int stopRecord;// 停止录像

// 写入到文件的参数
AVFormatContext *outFmtCtx = NULL;
AVOutputFormat *outFmt = NULL;

int muxer(const char *out_filename, int (*read_packet)(void *opaque, uint8_t *buf, int buf_size)) {
    if (out_filename == NULL) {
        printf("停止录像\n");
        stopRecord = 0;
        
        return -1;
    } else {
        stopRecord = 1;
    }
    
//    usleep(1000 * 10);
    
    // -------------- 1、申请一个AVIOContext --------------
    uint8_t *buf = av_mallocz(sizeof(uint8_t) * BUF_SIZE);
    pb = avio_alloc_context(buf, BUF_SIZE, 0, NULL, read_packet, NULL, NULL);
    if (!pb) {
        fprintf(stderr, "初始化avio失败!\n");
        return -1;
    }
    
    // -------------- 2、探测从内存中获取到的媒体流的格式 --------------
    if (av_probe_input_buffer(pb, &inFmt, "", NULL, 0, 0) < 0) {
        fprintf(stderr, "探测媒体流格式 失败!\n");
        return -1;
    } else {
        fprintf(stdout, "探测媒体流格式 成功!\n");
        fprintf(stdout, "format: %s[%s]\n", inFmt->name, inFmt->long_name);
    }
    
    inFmtCtx = avformat_alloc_context();
    // -------------- 3、这一步很关键 --------------
    inFmtCtx->pb = pb;
    
    // -------------- 4、打开流 --------------
    if (avformat_open_input(&inFmtCtx, "", inFmt, NULL) < 0) {
        fprintf(stderr, "无法打开输入流\n");
        return -1;
    }
    
    // -------------- 5、读取一部分视音频数据并且获得一些相关的信息 --------------
    if (avformat_find_stream_info(inFmtCtx, 0) < 0) {
        fprintf(stderr, "无法获取流信息.\n");
        return -1;
    }
    
    printf("========== 输入流信息格式 ==========\n");
    av_dump_format(inFmtCtx, 0, "", 0);
    printf("=================================\n");
    
    // -------------- 6、初始化输出文件 Output --------------
    avformat_alloc_output_context2(&outFmtCtx, NULL, NULL, out_filename);
    if (!outFmtCtx) {
        printf("未能初始化输出文件\n");
        goto end;
    }
    outFmt = outFmtCtx->oformat;
    
    // -------------- 7、找出videoindex、audioindex并建立输出AVStream --------------
    int i;
    for (i = 0; i < inFmtCtx->nb_streams; i++) {
        AVStream *stream = inFmtCtx->streams[i];
        
        // 找到video stream
        if(stream->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoindex = i;
        }
        
        // 找到audio stream
        if(stream->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            audioindex = i;
        }
        
        AVCodec *codec = avcodec_find_decoder(stream->codecpar->codec_id);
        AVCodecContext *pCodecCtx = avcodec_alloc_context3(codec);
        avcodec_parameters_to_context(pCodecCtx, stream->codecpar);
        
        AVStream *outStream = avformat_new_stream(outFmtCtx, pCodecCtx->codec);
        if (!outStream) {
            printf("创建输出流 失败\n");
            avcodec_free_context(&pCodecCtx);
            
            goto end;
        }
        
        // 赋值AVCodecContext的参数
        int ret = avcodec_parameters_from_context(outStream->codecpar, pCodecCtx);
        avcodec_free_context(&pCodecCtx);
        if (ret < 0) {
            printf( "赋值AVCodecContext的参数 失败\n");
            goto end;
        }
        
        outStream->codecpar->codec_tag = 0;
        
        if (outFmtCtx->oformat->flags & AVFMT_GLOBALHEADER) {
            AVCodec *outCodec = avcodec_find_decoder(outStream->codecpar->codec_id);
            AVCodecContext *outCodecCtx = avcodec_alloc_context3(outCodec);
            avcodec_parameters_to_context(outCodecCtx, outStream->codecpar);
            
            outCodecCtx->flags |= CODEC_FLAG_GLOBAL_HEADER;
            
            avcodec_free_context(&outCodecCtx);
        }
    }
    
    printf("========== 输出流信息格式 ==========\n");
    av_dump_format(outFmtCtx, 0, out_filename, 1);
    printf("==================================\n");
    
    // -------------- 8、avio_open 打开输出文件 --------------
    if (!(outFmt->flags & AVFMT_NOFILE)) {
        if (avio_open(&outFmtCtx->pb, out_filename, AVIO_FLAG_WRITE) < 0) {
            printf("不能打开输出文件 '%s'", out_filename);
            goto end;
        }
    }
    
    // -------------- 9、写入文件头 --------------
    if (avformat_write_header(outFmtCtx, NULL) < 0) {
        printf("写入文件头出错 \n");
        goto end;
    }
    
    // -------------- 10、循环读取AVPacket --------------
    while (1) {
        AVStream *in_stream = NULL, *out_stream = NULL;
        int stream_index = 0;
        
        // av_read_frame()：从输入文件读取一个AVPacket
        if(av_read_frame(inFmtCtx, &avPacket) >= 0) {
            do {
                in_stream = inFmtCtx->streams[avPacket.stream_index];
                out_stream = outFmtCtx->streams[stream_index];
                
                if(avPacket.stream_index == videoindex) {
                    if(avPacket.pts == AV_NOPTS_VALUE) {
                        // Write PTS
                        AVRational time_base1=in_stream->time_base;
                        // Duration between 2 frames (us)
                        int64_t calc_duration = (double)AV_TIME_BASE / av_q2d(in_stream->r_frame_rate);
                        // Parameters
                        avPacket.pts = (double)(frame_index*calc_duration) / (double)(av_q2d(time_base1) * AV_TIME_BASE);
                        avPacket.dts = avPacket.pts;
                        avPacket.duration = (double)calc_duration / (double)(av_q2d(time_base1) * AV_TIME_BASE);
                        frame_index++;
                    }
                    
                    break;
                }
                
                if(avPacket.stream_index == audioindex) {
                    if(avPacket.pts == AV_NOPTS_VALUE) {
                        // Write PTS
                        AVRational time_base1=in_stream->time_base;
                        // Duration between 2 frames (us)
                        int64_t calc_duration = (double)AV_TIME_BASE / av_q2d(in_stream->r_frame_rate);
                        // Parameters
                        avPacket.pts = (double)(frame_index*calc_duration)/(double)(av_q2d(time_base1)*AV_TIME_BASE);
                        avPacket.dts = avPacket.pts;
                        avPacket.duration = (double)calc_duration/(double)(av_q2d(time_base1)*AV_TIME_BASE);
                        frame_index++;
                    }
                    
                    break;
                }
            } while(av_read_frame(inFmtCtx, &avPacket) >= 0);
            
            // Convert PTS/DTS
            avPacket.pts = av_rescale_q_rnd(avPacket.pts,
                                            in_stream->time_base,
                                            out_stream->time_base,
                                            5 | 8192// (AVRounding)(AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX)
                                            );
            avPacket.dts = av_rescale_q_rnd(avPacket.dts,
                                            in_stream->time_base,
                                            out_stream->time_base,
                                            5 | 8192// (AVRounding)(AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX)
                                            );
            avPacket.duration = (int)av_rescale_q(avPacket.duration, in_stream->time_base, out_stream->time_base);
            avPacket.pos = -1;
            avPacket.stream_index = stream_index;
            
            // -------------- 11、写入一个AVPacket到输出文件 --------------
            printf("Write 1 Packet. size:%5d\tpts:%lld\n", avPacket.size, avPacket.pts);
            if (av_interleaved_write_frame(outFmtCtx, &avPacket) < 0) {
                printf("Error muxing packet\n");
                break;
            }
            
            av_packet_unref(&avPacket);
        } else {
            if (stopRecord == 0) {
                break;
            } else {
                usleep(10 * 1000);
            }
        }
    }
    
    // -------------- 12、写入文件尾 --------------
    av_write_trailer(outFmtCtx);
    
end:
    // close output
    if (outFmtCtx && !(outFmt->flags & AVFMT_NOFILE)) {
        avio_close(outFmtCtx->pb);
    }
    
    if (outFmtCtx) {
        avformat_free_context(outFmtCtx);
    }
    
    if (inFmtCtx) {
        avformat_free_context(inFmtCtx);
    }
    
    return 0;
}
