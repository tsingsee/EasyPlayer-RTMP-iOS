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

int stopRecord;// 停止录像

#pragma mark - 方法声明

AVFormatContext * muxerFromAudio(int (*read_packet)(void *opaque, uint8_t *buf, int buf_size));
AVFormatContext * muxerFromVideo(int (*read_packet)(void *opaque, uint8_t *buf, int buf_size));

#pragma mark - 主方法

int muxer(const char *out_filename,
          int (*read_video_packet)(void *opaque, uint8_t *buf, int buf_size),
          int (*read_audio_packet)(void *opaque, uint8_t *buf, int buf_size)) {
    if (out_filename == NULL) {
        printf("停止录像\n");
        stopRecord = 0;
        
        return -1;
    } else {
        stopRecord = 1;
    }
    
    // 网络流的参数
    AVFormatContext *video_inFmtCtx = NULL;
    AVFormatContext *audio_inFmtCtx = NULL;
    
    video_inFmtCtx = muxerFromVideo(read_video_packet);
    audio_inFmtCtx = muxerFromAudio(read_audio_packet);
    
    // 写入到文件的参数
    AVFormatContext *outFmtCtx = NULL;
    AVOutputFormat *outFmt = NULL;
    
    // -------------- 6、初始化输出文件 Output --------------
    avformat_alloc_output_context2(&outFmtCtx, NULL, NULL, out_filename);
    if (!outFmtCtx) {
        printf("未能初始化输出文件\n");
        goto end;
    }
    outFmt = outFmtCtx->oformat;
    
    int ret;
    int videoindex_in = -1, videoindex_out = -1;
    int audioindex_in = -1, audioindex_out = -1;
    int frame_index = 0;
    int64_t cur_video_pts = 0, cur_audio_pts = 0;
    
    // -------------- 7、找出videoindex、audioindex并建立输出AVStream --------------
    int i;
    if (video_inFmtCtx != NULL) {
        for (i = 0; i < video_inFmtCtx->nb_streams; i++) {
            //Create output AVStream according to input AVStream
            if(video_inFmtCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
                AVStream *in_stream = video_inFmtCtx->streams[i];
                
                AVCodec *in_codec = avcodec_find_decoder(in_stream->codecpar->codec_id);
                AVCodecContext *in_pCodecCtx = avcodec_alloc_context3(in_codec);// 需要使用avcodec_free_context释放
                avcodec_parameters_to_context(in_pCodecCtx, in_stream->codecpar);
                
                AVStream *out_stream = avformat_new_stream(outFmtCtx, in_pCodecCtx->codec);
                videoindex_in = i;
                if (!out_stream) {
                    printf("Failed allocating output stream\n");
                    ret = AVERROR_UNKNOWN;
                    
                    avcodec_free_context(&in_pCodecCtx);
                    
                    goto end;
                }
                
                videoindex_out = out_stream->index;
                
                // 赋值AVCodecContext的参数 Copy the settings of AVCodecContext
                ret = avcodec_parameters_from_context(out_stream->codecpar, in_pCodecCtx);
                
                avcodec_free_context(&in_pCodecCtx);
                
                if (ret < 0) {
                    printf("Failed to copy context from input to output stream codec context\n");
                    goto end;
                }
                
                out_stream->codecpar->codec_tag = 0;
                
                if (outFmtCtx->oformat->flags & AVFMT_GLOBALHEADER) {
                    AVCodec *out_codec = avcodec_find_decoder(out_stream->codecpar->codec_id);
                    AVCodecContext *out_pCodecCtx = avcodec_alloc_context3(out_codec);// 需要使用avcodec_free_context释放
                    avcodec_parameters_to_context(out_pCodecCtx, out_stream->codecpar);
                    
                    out_pCodecCtx->flags |= CODEC_FLAG_GLOBAL_HEADER;
                    
                    avcodec_free_context(&out_pCodecCtx);
                }
                
                break;
            }
        }
    }
    
    if (audio_inFmtCtx != NULL) {
        for (i = 0; i < audio_inFmtCtx->nb_streams; i++) {
            //Create output AVStream according to input AVStream
            if(audio_inFmtCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
                AVStream *in_stream = audio_inFmtCtx->streams[i];
                
                AVCodec *in_codec = avcodec_find_decoder(in_stream->codecpar->codec_id);
                AVCodecContext *in_pCodecCtx = avcodec_alloc_context3(in_codec);// 需要使用avcodec_free_context释放
                avcodec_parameters_to_context(in_pCodecCtx, in_stream->codecpar);
                
                AVStream *out_stream = avformat_new_stream(outFmtCtx, in_pCodecCtx->codec);
                audioindex_in = i;
                if (!out_stream) {
                    printf( "Failed allocating output stream\n");
                    ret = AVERROR_UNKNOWN;
                    
                    avcodec_free_context(&in_pCodecCtx);
                    
                    goto end;
                }
                
                audioindex_out = out_stream->index;
                
                // 赋值AVCodecContext的参数 Copy the settings of AVCodecContext
                ret = avcodec_parameters_from_context(out_stream->codecpar, in_pCodecCtx);
                
                avcodec_free_context(&in_pCodecCtx);
                
                if (ret < 0) {
                    printf("Failed to copy context from input to output stream codec context\n");
                    goto end;
                }
                
                out_stream->codecpar->codec_tag = 0;
                
                if (outFmtCtx->oformat->flags & AVFMT_GLOBALHEADER) {
                    AVCodec *out_codec = avcodec_find_decoder(out_stream->codecpar->codec_id);
                    AVCodecContext *out_pCodecCtx = avcodec_alloc_context3(out_codec);// 需要使用avcodec_free_context释放
                    avcodec_parameters_to_context(out_pCodecCtx, out_stream->codecpar);
                    
                    out_pCodecCtx->flags |= CODEC_FLAG_GLOBAL_HEADER;
                    
                    avcodec_free_context(&out_pCodecCtx);
                }
                
                break;
            }
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
        printf("写入文件头出错\n");
        goto end;
    }
    
    AVPacket avPacket;
    
    // -------------- 10、循环读取AVPacket --------------
    while (1) {
        int write_video = -1;
        
        if (videoindex_in != -1 && audioindex_in == -1) {// 只合成视频
            write_video = 1;
        } else if (videoindex_in == -1 && audioindex_in != -1) {// 只合成音频
            write_video = 0;
        } else if (videoindex_in != -1 && audioindex_in != -1) {   // ---- 同时合成视频和音频 ----
            // av_compare_ts()：比较时间戳，决定写入视频还是写入音频 Get an AVPacket
            int ts = av_compare_ts(cur_video_pts,
                                   video_inFmtCtx->streams[videoindex_in]->time_base,
                                   cur_audio_pts,
                                   audio_inFmtCtx->streams[audioindex_in]->time_base);
            if(ts <= 0) {
                write_video = 1;
            } else {
                write_video = 0;
            }
        }
        
        AVFormatContext *ifmt_ctx;
        AVStream *in_stream, *out_stream;
        int stream_index = 0;
        
        if(write_video == 1) {
            // Video
            ifmt_ctx = video_inFmtCtx;
            stream_index = videoindex_out;
            
            // av_read_frame()：从输入文件读取一个AVPacket
            if(av_read_frame(ifmt_ctx, &avPacket) >= 0) {
                do {
                    in_stream  = ifmt_ctx->streams[avPacket.stream_index];
                    out_stream = outFmtCtx->streams[stream_index];
                    
                    if(avPacket.stream_index == videoindex_in) {
                        // FIX：No PTS (Example: Raw H.264)
                        // Simple Write PTS
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
                        
                        cur_video_pts = avPacket.pts;
                        break;
                    }
                } while(av_read_frame(ifmt_ctx, &avPacket) >= 0);
                
                // Convert PTS/DTS
                avPacket.pts = av_rescale_q_rnd(avPacket.pts,
                                                in_stream->time_base,
                                                out_stream->time_base,
                                                // (AVRounding)(AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX)
                                                5 | 8192
                                                );
                avPacket.dts = av_rescale_q_rnd(avPacket.dts,
                                                in_stream->time_base,
                                                out_stream->time_base,
                                                // (AVRounding)(AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX)
                                                5 | 8192
                                                );
                avPacket.duration = (int)av_rescale_q(avPacket.duration, in_stream->time_base, out_stream->time_base);
                avPacket.pos = -1;
                avPacket.stream_index=stream_index;
                
                //                printf("Write 1 video Packet. size:%5d\tpts:%lld\n", avPacket.size, avPacket.pts);
                
                // av_interleaved_write_frame()：写入一个AVPacket到输出文件
                if (av_interleaved_write_frame(outFmtCtx, &avPacket) < 0) {
                    printf( "Error muxing packet\n");
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
        } else if(write_video == 0) {
            // Audio
            ifmt_ctx = audio_inFmtCtx;
            stream_index = audioindex_out;
            if(av_read_frame(ifmt_ctx, &avPacket) >= 0) {
                do {
                    in_stream = ifmt_ctx->streams[avPacket.stream_index];
                    out_stream = outFmtCtx->streams[stream_index];
                    
                    if(avPacket.stream_index == audioindex_in) {
                        // FIX：No PTS
                        // Simple Write PTS
                        if(avPacket.pts == AV_NOPTS_VALUE){
                            // Write PTS
                            AVRational time_base1=in_stream->time_base;
                            // Duration between 2 frames (us)
                            int64_t calc_duration=(double)AV_TIME_BASE/av_q2d(in_stream->r_frame_rate);
                            // Parameters
                            avPacket.pts = (double)(frame_index*calc_duration)/(double)(av_q2d(time_base1)*AV_TIME_BASE);
                            avPacket.dts = avPacket.pts;
                            avPacket.duration = (double)calc_duration/(double)(av_q2d(time_base1)*AV_TIME_BASE);
                            frame_index++;
                        }
                        
                        cur_audio_pts = avPacket.pts;
                        
                        break;
                    }
                } while(av_read_frame(ifmt_ctx, &avPacket) >= 0);
                
                // Convert PTS/DTS
                avPacket.pts = av_rescale_q_rnd(avPacket.pts,
                                                in_stream->time_base,
                                                out_stream->time_base,
                                                // (AVRounding)(AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX)
                                                5 | 8192
                                                );
                avPacket.dts = av_rescale_q_rnd(avPacket.dts,
                                                in_stream->time_base,
                                                out_stream->time_base,
                                                // (AVRounding)(AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX)
                                                5 | 8192
                                                );
                avPacket.duration = (int)av_rescale_q(avPacket.duration, in_stream->time_base, out_stream->time_base);
                avPacket.pos = -1;
                avPacket.stream_index=stream_index;
                
                //                printf("Write 1 audio Packet. size:%5d\tpts:%lld\n", avPacket.size, avPacket.pts);
                
                // av_interleaved_write_frame()：写入一个AVPacket到输出文件
                if (av_interleaved_write_frame(outFmtCtx, &avPacket) < 0) {
                    printf( "Error muxing packet\n");
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
    
    if (video_inFmtCtx) {
        avformat_free_context(video_inFmtCtx);
    }
    
    if (audio_inFmtCtx) {
        avformat_free_context(audio_inFmtCtx);
    }
    
    return 0;
}

#pragma mark - 分别生成AVIOContext，获取视频/音频的格式

AVFormatContext * muxerFromVideo(int (*read_packet)(void *opaque, uint8_t *buf, int buf_size)) {
    // -------------- 1、申请一个AVIOContext --------------
    uint8_t *buf = av_mallocz(sizeof(uint8_t) * BUF_SIZE);
    AVIOContext *pb = avio_alloc_context(buf, BUF_SIZE, 0, NULL, read_packet, NULL, NULL);
    if (!pb) {
        fprintf(stderr, "初始化<视频>video_pb失败!\n");
        return NULL;
    }
    
    AVInputFormat *inFmt = NULL;
    
    // -------------- 2、探测从内存中获取到的媒体流的格式 --------------
    if (av_probe_input_buffer(pb, &inFmt, "", NULL, 0, 0) < 0) {
        fprintf(stderr, "探测<视频>媒体流格式 失败!\n");
        return NULL;
    } else {
        fprintf(stdout, "探测<视频>媒体流格式 成功!\n");
        fprintf(stdout, "format: %s[%s]\n", inFmt->name, inFmt->long_name);
    }
    
    AVFormatContext *video_inFmtCtx = avformat_alloc_context();
    // -------------- 3、这一步很关键 --------------
    video_inFmtCtx->pb = pb;
    
    // -------------- 4、打开流 --------------
    if (avformat_open_input(&video_inFmtCtx, "", inFmt, NULL) < 0) {
        fprintf(stderr, "无法打开<视频>输入流\n");
        return NULL;
    }
    
    // -------------- 5、读取一部分视频数据并且获得一些相关的信息 --------------
    if (avformat_find_stream_info(video_inFmtCtx, 0) < 0) {
        fprintf(stderr, "无法获取<视频>流信息.\n");
        return NULL;;
    }
    
    printf("========== <视频>输入流信息格式 ==========\n");
    av_dump_format(video_inFmtCtx, 0, "", 0);
    printf("=======================================\n");
    
    return video_inFmtCtx;
}

AVFormatContext * muxerFromAudio(int (*read_packet)(void *opaque, uint8_t *buf, int buf_size)) {
    // -------------- 1、申请一个AVIOContext --------------
    uint8_t *buf = av_mallocz(sizeof(uint8_t) * BUF_SIZE);
    AVIOContext *pb = avio_alloc_context(buf, BUF_SIZE, 0, NULL, read_packet, NULL, NULL);
    if (!pb) {
        fprintf(stderr, "初始化<音频>audio_pb失败!\n");
        return NULL;
    }
    
    AVInputFormat *inFmt = NULL;
    
    // -------------- 2、探测从内存中获取到的媒体流的格式 --------------
    int ret = av_probe_input_buffer(pb, &inFmt, "", NULL, 0, 0);
    if (ret < 0) {
        fprintf(stderr, "探测<音频>媒体流格式 失败!\n");
        return NULL;
    } else {
        fprintf(stdout, "探测<音频>媒体流格式 成功!\n");
        fprintf(stdout, "format: %s[%s]\n", inFmt->name, inFmt->long_name);
    }
    
    AVFormatContext *audio_inFmtCtx = avformat_alloc_context();
    // -------------- 3、这一步很关键 --------------
    audio_inFmtCtx->pb = pb;
    
    // -------------- 4、打开流 --------------
    if (avformat_open_input(&audio_inFmtCtx, "", inFmt, NULL) < 0) {
        fprintf(stderr, "无法打开<音频>输入流\n");
        return NULL;
    }
    
    // -------------- 5、读取一部分音频数据并且获得一些相关的信息 --------------
    if (avformat_find_stream_info(audio_inFmtCtx, 0) < 0) {
        fprintf(stderr, "无法获取<音频>流信息.\n");
        return NULL;
    }
    
    printf("========== <音频>输入流信息格式 ==========\n");
    av_dump_format(audio_inFmtCtx, 0, "", 0);
    printf("=======================================\n");
    
    return audio_inFmtCtx;
}
