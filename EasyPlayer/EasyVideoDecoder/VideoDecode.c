//

#include "VideoDecode.h"

static IDECODE_METHODE s_uiDecodeMethod = IDM_SW;

unsigned char H264_SPS_PPS_NEW[] = {
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

void setupScaler(DEC_COMPONENT *pComponent, int nWidth, int nHeight) {
    // Allocate RGB picture
    avpicture_alloc(&pComponent->picture, AV_PIX_FMT_RGB24, nWidth, nHeight);
    
    // Setup scaler
    static int sws_flags =  SWS_FAST_BILINEAR;
    
    /** 设置SwsContext
     该函数包含以下参数：
     srcW：源图像的宽
     srcH：源图像的高
     srcFormat：源图像的像素格式
     dstW：目标图像的宽
     dstH：目标图像的高
     dstFormat：目标图像的像素格式
     flags：设定图像拉伸使用的算法
     成功执行的话返回生成的SwsContext，否则返回NULL。
     */
    pComponent->pImgConvertCtx = sws_getContext(pComponent->pCodecCtx->width,
                                                pComponent->pCodecCtx->height,
                                                pComponent->pCodecCtx->pix_fmt,
                                                nWidth,
                                                nHeight,
                                                AV_PIX_FMT_RGB24,
                                                sws_flags, NULL, NULL, NULL);
}

void DecodeRegiestAll() {
    // [1]、注册所支持的所有的文件（容器）格式及其对应的CODEC
    av_register_all();
}

void *DecodeCreate(DEC_CREATE_PARAM *pCreateParam) {
    DEC_COMPONENT *pComponent = (DEC_COMPONENT *)malloc(sizeof(DEC_COMPONENT));
    pComponent->pCodecCtx = NULL;
    pComponent->pFrame = NULL;
    pComponent->pImgConvertCtx = NULL;
    s_uiDecodeMethod = pCreateParam->method;
    
    // [5]、avcodec_find_decoder()查找解码器
    AVCodec *pCodec = avcodec_find_decoder(pCreateParam->avCodecID);
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
    p1 = H264_SPS_PPS_NEW;
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

unsigned int DecodeVideo(void *DecHandle, DEC_DECODE_PARAM *pDecodeParam, DVDVideoPicture *picture) {
    DEC_COMPONENT *pComponent = (DEC_COMPONENT *)DecHandle;
    if (pComponent == NULL || pComponent->pCodecCtx == NULL || pComponent->pFrame == NULL) {
        return 0;
    }
    
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
        packet.size = pDecodeParam->nLen;       // data的大小
        packet.data = pDecodeParam->pStream;    // 压缩编码的数据
    }
    
    int got_picture = 0;
    
    int nRet = 0;
    if (packet.size > 0) {
        // [9]、解码一帧数据,输入一个压缩编码的结构体AVPacket-->输出一个解码后的结构体AVFrame
        nRet = avcodec_decode_video2(pComponent->pCodecCtx,
                                     pComponent->pFrame,
                                     &got_picture,
                                     &packet);
        
        if (nRet == -1) {
            return nRet;
        }
    }
    
    // 释放packet
    av_packet_unref(&packet);
    
    pComponent->newStreamLen = pComponent->uiOriginLen;
    //    printf("帧类型AVPictureType：%d\n", pComponent->pFrame->pict_type);
    if (pComponent->pFrame->data[0] == NULL) {
        return 0;
    }
    
    if (got_picture) {
        pDecodeParam->nOutWidth = pComponent->pFrame->width;
        pDecodeParam->nOutHeight = pComponent->pFrame->height;
        
        // 只有在解出一帧的时候pCodecCtx的宽度和高度才是实际的值
        if (s_uiDecodeMethod == IDM_SW) {
            if (!pComponent->bScaleCreated) {
                setupScaler(pComponent, picture->iDisplayWidth, picture->iDisplayHeight);
                pComponent->bScaleCreated = !pComponent->bScaleCreated;
            }
            
            // convert Frame to RGB。处理图像数据,用于转换像素
            // data解码后的图像像素数据
            sws_scale(pComponent->pImgConvertCtx,
                      (const uint8_t* const*)pComponent->pFrame->data,
                      pComponent->pFrame->linesize, // linesize对视频来说是一行像素的大小。data中“一行”数据的大小。注意：未必等于图像的宽，一般大于图像的宽。
                      0,
                      pComponent->pCodecCtx->height,
                      pComponent->picture.data,
                      pComponent->picture.linesize);
            pDecodeParam->pImgRGB = pComponent->picture.data[0];
            pDecodeParam->nLineSize = pComponent->picture.linesize[0];
        } else {
            picture->iWidth = pComponent->pCodecCtx->width;
            picture->iHeight = pComponent->pCodecCtx->height;
            picture->chroma_position = pComponent->pCodecCtx->chroma_sample_location;
            picture->color_primaries = pComponent->pCodecCtx->color_primaries;
            picture->color_transfer = pComponent->pCodecCtx->color_trc;
            
            // qscale_table:QP表。QP表指向一块内存，里面存储的是每个宏块的QP值。宏块的标号是从左往右，一行一行的来的。每个宏块对应1个QP。
            picture->qscale_table = pComponent->pFrame->qscale_table;
            
            //
            picture->qscale_stride = pComponent->pFrame->qstride;
            
            for (int i = 0; i < 4; i++) {
                picture->data[i] = pComponent->pFrame->data[i];
                picture->iLineSize[i] = pComponent->pFrame->linesize[i];
            }
        }
    }
    
    pDecodeParam->pFrame = pComponent->pFrame;
    pDecodeParam->pCodecCtx = pComponent->pCodecCtx;
    
    return got_picture != 0;
}

void DecodeClose(void *DecHandle) {
    DEC_COMPONENT *pComponent = (DEC_COMPONENT *)DecHandle;
    
    if (pComponent != NULL) {
        if (pComponent->pImgConvertCtx != NULL) {
            sws_freeContext(pComponent->pImgConvertCtx);
            pComponent->pImgConvertCtx = NULL;
        }
        
        if (pComponent->bScaleCreated) {
            // Free RGB picture
            avpicture_free(&pComponent->picture);
        }
        
        // Free the YUV frame
        if (pComponent->pFrame != NULL) {
            av_frame_free(&pComponent->pFrame);
            pComponent->pFrame = NULL;
        }
        
        // Close the codec
        if (pComponent->pCodecCtx != NULL) {
            avcodec_free_context(&pComponent->pCodecCtx);
            pComponent->pCodecCtx = NULL;
        }
        
        free(pComponent->pNewStream);
        pComponent->pNewStream = 0;
        pComponent->newStreamLen = 0;
        
        s_uiDecodeMethod = IDM_SW;
    }
}
