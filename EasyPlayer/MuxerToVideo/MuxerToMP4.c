//
//  MuxerToMP4.c
//  EasyPlayer
//
//  Created by liyy on 2017/12/19.
//  Copyright © 2017年 cs. All rights reserved.
//

#include "MuxerToMP4.h"
#include "libavformat/avformat.h"
#include "libavutil/mathematics.h"

/*
 FIX: H.264 in some container format (FLV, MP4, MKV etc.) need
 "h264_mp4toannexb" bitstream filter (BSF)
 *Add SPS,PPS in front of IDR frame
 *Add start code ("0,0,0,1") in front of NALU
 H.264 in some container (MPEG2TS) don't need this BSF.
 */
//'1': Use H.264 Bitstream Filter
#define USE_H264BSF 0

/*
 FIX:AAC in some container format (FLV, MP4, MKV etc.) need
 "aac_adtstoasc" bitstream filter (BSF)
 */
//'1': Use AAC Bitstream Filter
#define USE_AACBSF 0

int muxerToMP4(const char *in_filename_v, const char *in_filename_a, const char *out_filename) {
    
    // Output AVFormatContext
    AVFormatContext *outFmtCtx = NULL;
    AVOutputFormat *outFmt = NULL;
    
    // Input AVFormatContext
    AVFormatContext *inFmtCtx_v = NULL;
    AVFormatContext *inFmtCtx_a = NULL;
    
    AVPacket avPacket;
    
    int ret;
    
    int videoindex_in = -1, videoindex_out = -1;
    int audioindex_in = -1, audioindex_out = -1;
    
    int frame_index = 0;
    
    int64_t cur_video_pts = 0, cur_audio_pts = 0;
    
    av_register_all();
    
    // 打开输入文件 Input
    if ((ret = avformat_open_input(&inFmtCtx_v, in_filename_v, 0, 0)) < 0) {
        printf( "Could not open input file.");
        goto end;
    }
    if ((ret = avformat_find_stream_info(inFmtCtx_v, 0)) < 0) {
        printf( "Failed to retrieve input stream information");
        goto end;
    }

    if ((ret = avformat_open_input(&inFmtCtx_a, in_filename_a, 0, 0)) < 0) {
        printf( "Could not open input file.");
        goto end;
    }
    if ((ret = avformat_find_stream_info(inFmtCtx_a, 0)) < 0) {
        printf( "Failed to retrieve input stream information");
        goto end;
    }
    
    printf("========== 输入流信息格式 ==========\n");
    av_dump_format(inFmtCtx_v, 0, in_filename_v, 0);
    printf("---------------------------------\n");
    av_dump_format(inFmtCtx_a, 0, in_filename_a, 0);
    printf("==================================\n");
    
    // 初始化输出文件 Output
    avformat_alloc_output_context2(&outFmtCtx, NULL, NULL, out_filename);
    if (!outFmtCtx) {
        printf("Could not create output context\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }
    outFmt = outFmtCtx->oformat;
    
    int i;
    for (i = 0; i < inFmtCtx_v->nb_streams; i++) {
        //Create output AVStream according to input AVStream
        if(inFmtCtx_v->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            AVStream *in_stream = inFmtCtx_v->streams[i];
            
            AVCodec *in_codec = avcodec_find_decoder(in_stream->codecpar->codec_id);
            AVCodecContext *in_pCodecCtx = avcodec_alloc_context3(in_codec);// 需要使用avcodec_free_context释放
            avcodec_parameters_to_context(in_pCodecCtx, in_stream->codecpar);
            
            AVStream *out_stream = avformat_new_stream(outFmtCtx, in_pCodecCtx->codec);
            videoindex_in = i;
            if (!out_stream) {
                printf( "Failed allocating output stream\n");
                ret = AVERROR_UNKNOWN;
                
                avcodec_free_context(&in_pCodecCtx);
                
                goto end;
            }
            
            videoindex_out = out_stream->index;
            
            // 赋值AVCodecContext的参数 Copy the settings of AVCodecContext
            ret = avcodec_parameters_from_context(out_stream->codecpar, in_pCodecCtx);
            
            avcodec_free_context(&in_pCodecCtx);
            
            if (ret < 0) {
                printf( "Failed to copy context from input to output stream codec context\n");
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

    for (i = 0; i < inFmtCtx_a->nb_streams; i++) {
        //Create output AVStream according to input AVStream
        if(inFmtCtx_a->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            AVStream *in_stream = inFmtCtx_a->streams[i];
            
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
                printf( "Failed to copy context from input to output stream codec context\n");
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
    
    printf("========== 输出流信息格式 ==========\n");
    av_dump_format(outFmtCtx, 0, out_filename, 1);
    printf("==================================\n");
    
    // avio_open 打开输出文件
    if (!(outFmt->flags & AVFMT_NOFILE)) {
        if (avio_open(&outFmtCtx->pb, out_filename, AVIO_FLAG_WRITE) < 0) {
            printf( "Could not open output file '%s'", out_filename);
            goto end;
        }
    }

    // 写入文件头 Write file header
    if (avformat_write_header(outFmtCtx, NULL) < 0) {
        printf( "Error occurred when opening output file\n");
        goto end;
    }

    // FIX
#if USE_H264BSF
    AVBitStreamFilterContext *h264bsfc = av_bitstream_filter_init("h264_mp4toannexb");
#endif

#if USE_AACBSF
    AVBitStreamFilterContext *aacbsfc = av_bitstream_filter_init("aac_adtstoasc");
#endif

    while (1) {
        AVFormatContext *ifmt_ctx;
        int stream_index = 0;
        AVStream *in_stream, *out_stream;
        
        // av_compare_ts()：比较时间戳，决定写入视频还是写入音频 Get an AVPacket
        if(av_compare_ts(cur_video_pts,
                         inFmtCtx_v->streams[videoindex_in]->time_base,
                         cur_audio_pts,
                         inFmtCtx_a->streams[audioindex_in]->time_base) <= 0) {
            // Video
            ifmt_ctx = inFmtCtx_v;
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
            } else {
                break;
            }
        } else {
            // Audio
            ifmt_ctx = inFmtCtx_a;
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
            } else {
                break;
            }
        }

        // FIX:Bitstream Filter
#if USE_H264BSF
        av_bitstream_filter_filter(h264bsfc,
                                   in_stream->codec,
                                   NULL,
                                   &avPacket.data,
                                   &avPacket.size,
                                   avPacket.data,
                                   avPacket.size,
                                   0);
#endif

#if USE_AACBSF
        av_bitstream_filter_filter(aacbsfc,
                                   out_stream->codec,
                                   NULL,
                                   &avPacket.data,
                                   &avPacket.size,
                                   avPacket.data,
                                   avPacket.size,
                                   0);
#endif

        // Convert PTS/DTS
        avPacket.pts = av_rescale_q_rnd(avPacket.pts,
                                   in_stream->time_base,
                                   out_stream->time_base,
//                                   (AVRounding)(AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX)
                                   5 | 8192
                                   );
        avPacket.dts = av_rescale_q_rnd(avPacket.dts,
                                   in_stream->time_base,
                                   out_stream->time_base,
//                                   (AVRounding)(AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX)
                                   5 | 8192
                                   );
        avPacket.duration = (int)av_rescale_q(avPacket.duration, in_stream->time_base, out_stream->time_base);
        avPacket.pos = -1;
        avPacket.stream_index=stream_index;

        printf("Write 1 Packet. size:%5d\tpts:%lld\n", avPacket.size, avPacket.pts);

        // av_interleaved_write_frame()：写入一个AVPacket到输出文件
        if (av_interleaved_write_frame(outFmtCtx, &avPacket) < 0) {
            printf( "Error muxing packet\n");
            break;
        }

        av_packet_unref(&avPacket);
    }

    // av_write_trailer()：写入文件尾 Write file trailer
    av_write_trailer(outFmtCtx);

#if USE_H264BSF
    av_bitstream_filter_close(h264bsfc);
#endif
#if USE_AACBSF
    av_bitstream_filter_close(aacbsfc);
#endif

end:
    avformat_close_input(&inFmtCtx_v);
    avformat_close_input(&inFmtCtx_a);

    // close output
    if (outFmtCtx && !(outFmt->flags & AVFMT_NOFILE)) {
        avio_close(outFmtCtx->pb);
    }

    avformat_free_context(outFmtCtx);

    if (ret < 0 && ret != AVERROR_EOF) {
        printf( "Error occurred.\n");
        return -1;
    }

    return 0;
}
