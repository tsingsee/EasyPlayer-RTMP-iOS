//
#include "AACDecoder.h"

#define AVCODEC_MAX_AUDIO_FRAME_SIZE	192000

void *aac_decoder_create(enum AVCodecID codecid,    // 解码器ID
                         int sample_rate,           // 采样率(44.1kHZ)
                         int channels,              // 声道数(2)
                         int bit_rate) {            // 码率( = 采样位数(bit) × 采样频率(HZ) × 声道数)
    AACDFFmpeg *pComponent = (AACDFFmpeg *)malloc(sizeof(AACDFFmpeg));
    
    // [5]、avcodec_find_decoder()查找解码器
    AVCodec *pCodec = avcodec_find_decoder(codecid);//AV_CODEC_ID_AAC
    if (pCodec == NULL) {
		printf("find %d decoder error", codecid);
        return 0;
    }
    
	printf("aac_decoder_create codecid=%d\r\n", codecid);
    
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

int aac_decode_frame(void *pParam,
                     unsigned char *pData,
                     int nLen,
                     unsigned char *pPCM,
                     unsigned int *outLen) {
	int pkt_pos = 0;
	int src_len = 0;
	int dst_len = 0;
    
    AACDFFmpeg *pAACD = (AACDFFmpeg *)pParam;
    
    AVPacket packet;
    av_init_packet(&packet);
    
    packet.size = nLen;
    packet.data = pData;
    
//    int got_frame = 0;

	while (pkt_pos < nLen) {
        int got_frame = 0;
        
        // 解码
		src_len = avcodec_decode_audio4(pAACD->pCodecCtx, pAACD->pFrame, &got_frame, &packet);
		if (src_len < 0) {
			return -3;
		}
        
		if (got_frame) {
			uint8_t *out[] = {pAACD->audio_buf};
            
            /* 开始重采样
             目前，FFmpeg3.0 avcodec_decode_audio4函数解码出来的音频数据是单精度浮点类型，值范围为[0, 1.0]。
             iOS可播放Float类型的音频数据，范围和FFmpeg解码出来的PCM不同，故需要进行重采样
             */
			int needed_buf_size = av_samples_get_buffer_size(NULL,
                                                             pAACD->pCodecCtx->channels,
                                                             pAACD->pFrame->nb_samples,
                                                             AV_SAMPLE_FMT_S16,
                                                             1);
            
            // pAACD->au_convert_ctx 重采样上下文
            // swr_convert:将给定的音频源的声道、声道布局和采样率转换为输出设备的声道、声道布局和采样率
			int len = swr_convert(pAACD->au_convert_ctx,
                                  out,
                                  needed_buf_size,
                                  (const uint8_t **)pAACD->pFrame->data,
                                  pAACD->pFrame->nb_samples);
			if (len > 0) {
                // 将转换后的数据复制给pFrame
				len = len * pAACD->pCodecCtx->channels * av_get_bytes_per_sample(AV_SAMPLE_FMT_S16);
//                soundFile.Write((unsigned char *)audio_buf, len);
				memcpy(pPCM+dst_len, pAACD->audio_buf, len);
			}
            
			dst_len += len;
		}
        
		pkt_pos += src_len;
		packet.data = pData + pkt_pos;
		packet.size = nLen - pkt_pos;
	}
    
    if (NULL != outLen)	{
        *outLen = dst_len;
    }
    
//    av_free_packet(&packet);
    av_packet_unref(&packet);
	
    return (dst_len > 0) ? 0 : -1;
}

void aac_decode_close(void *pParam) {
    AACDFFmpeg *pComponent = (AACDFFmpeg *)pParam;
    if (pComponent == NULL) {
        return;
    }
    
    // 关闭重采样
    swr_free(&pComponent->au_convert_ctx);
    
    if (pComponent->pFrame != NULL) {
        // 释放解码后的音频帧数据
        av_frame_free(&pComponent->pFrame);
        pComponent->pFrame = NULL;
    }
    
    if (pComponent->pCodecCtx != NULL) {
        // 释放解码器
        avcodec_close(pComponent->pCodecCtx);
        avcodec_free_context(&pComponent->pCodecCtx);
        pComponent->pCodecCtx = NULL;
    }
    
    free(pComponent);
}
