//
//  ffplayer_decoder.c
//  ffmpegDemo
//
//  Created by 天明 on 2017/11/30.
//  Copyright © 2017年 天明. All rights reserved.
//

#include "ffplayer_decoder.h"
#include <unistd.h>

static VideoState *global_video_state;

void packet_queue_init(PacketQueue *q) {
    memset(q, 0, sizeof(PacketQueue));
    q->mutex = SDL_CreateMutex();
    q->cond = SDL_CreateCond();

}

int packet_queue_put(PacketQueue *q, AVPacket *pkt) {
    
    AVPacketList *pkt1;
    if(av_dup_packet(pkt) < 0) {
        return -1;
    }
    pkt1 = av_malloc(sizeof(AVPacketList));
    if (!pkt1)
        return -1;
    pkt1->pkt = *pkt;
    pkt1->next = NULL;
    
    SDL_LockMutex(q->mutex);
    
    if (!q->last_pkt)
        q->first_pkt = pkt1;
    else
        q->last_pkt->next = pkt1;
    q->last_pkt = pkt1;
    q->nb_packets++;
    q->size += pkt1->pkt.size;
    SDL_CondSignal(q->cond);
    
    SDL_UnlockMutex(q->mutex);
    return 0;
}

int packet_queue_get(PacketQueue *q, AVPacket *pkt, int block)
{
    AVPacketList *pkt1;
    int ret;
    
    ret =  SDL_LockMutex(q->mutex);
    
    for(;;) {
        if(global_video_state->quit) {
            ret = -1; break;
        }
        pkt1 = q->first_pkt;
        if (pkt1) {
            q->first_pkt = pkt1->next;
            if (!q->first_pkt)
                q->last_pkt = NULL;
            q->nb_packets--;
            q->size -= pkt1->pkt.size;
            *pkt = pkt1->pkt;
            av_free(pkt1);
            ret = 1;
            break;
        } else if (!block) {
            ret = 0;
            break;
        } else {
            if (global_video_state->end) {
                ret = -1;
                break;
            }
            SDL_CondWait(q->cond, q->mutex);
        }
    }
    SDL_UnlockMutex(q->mutex);
    return ret;
}

int stream_component_open(VideoState *is, enum AVMediaType type) {
    AVFormatContext *fmt_ctx;
    int stream_idx;
    AVStream *stream;
    AVCodec *code;
    AVCodecContext *code_ctx;
    fmt_ctx = is->fmt_ctx;
    int ret = 0;
    const char *type_string = av_get_media_type_string(type);
    //找到音频和视频流的 index,
    stream_idx = av_find_best_stream(fmt_ctx, type, -1, -1, NULL, 0);
    if (stream_idx < 0) {
        printf("Could not find %s stream in input file\n", av_get_media_type_string(type));
        return -1;
    }
    //根据index找到对应的stream
    stream = fmt_ctx->streams[stream_idx];
    if (!stream) {
        printf("Could not find %s stream in the input, aborting\n", type_string);
        return -1;
    }
    /* find decoder for the stream */
    code = avcodec_find_decoder(stream->codecpar->codec_id);
    if (!code) {
        printf("Failed to find %s codec\n", type_string);
        return -1;
    }
    /* Allocate a codec context for the decoder */
    code_ctx = avcodec_alloc_context3(code);
    if (!code_ctx) {
        printf("Failed to allocate the %s codec context\n", type_string);
        return -1;
    }
    /* Copy codec parameters from input stream to output codec context */
    if ((ret = avcodec_parameters_to_context(code_ctx, stream->codecpar)) < 0) {
        printf("Failed to copy %s codec parameters to decoder context\n", type_string);
        return -1;
    }
    static int refcount;
    refcount = 0;
    /* Init the decoders, with or without reference counting */
    AVDictionary *opts = NULL;
    av_dict_set(&opts, "refcounted_frames", refcount ? "1" : "0", 0);
    if ((ret = avcodec_open2(code_ctx, code, &opts)) < 0) {
        printf("Failed to open %s codec\n", type_string);
        return -1;
    }
    if (type == AVMEDIA_TYPE_AUDIO) {
        is->audio_stream_idx = stream_idx;
        is->audio_stream = stream;
        is->audio_code = code;
        is->audio_ctx = code_ctx;
        is->audio_buf_size = 0;
        is->audio_buf_index = 0;
        memset(&is->audio_pkt, 0, sizeof(is->audio_pkt));
        packet_queue_init(&is->audioq);
        is->audio_swr_ctx = NULL;
    } else if (type == AVMEDIA_TYPE_VIDEO) {
        is->video_stream_idx = stream_idx;
        is->video_stream = stream;
        is->video_code = code;
        is->video_ctx = code_ctx;
        is->frame_timer = (double)av_gettime() / 1000000.0;
        is->frame_last_delay = 40e-3;
        packet_queue_init(&is->videoq);
        is->video_tid = SDL_CreateThread(video_thread, is);
        is->vodeo_sws_ctx = sws_getContext(is->video_ctx->width, is->video_ctx->height, is->video_ctx->pix_fmt,
                                           is->video_ctx->width, is->video_ctx->height, AV_PIX_FMT_YUV420P,
                                           SWS_BILINEAR, NULL, NULL, NULL
                                           );
    }
    return 0;
}

int decode_thread(void *data) {
    VideoState *is = (VideoState *)data;
    AVFormatContext *fmt_ctx = is->fmt_ctx;
    int ret = 0;
    global_video_state = is;
    //    AVPacket pkt1, *packet = &pkt1;
    //打开文件
    ret = avformat_open_input(&fmt_ctx, is->src_filename, NULL, NULL);
    if (ret < 0) {
        printf("Could not open source file\n");
        return -1;
    }
    //找到流信息
    ret = avformat_find_stream_info(fmt_ctx, 0);
    if (ret < 0) {
        printf("Could not find stream information\n");
        return -1;
    }
    is->fmt_ctx = fmt_ctx;
    ret = stream_component_open(is, AVMEDIA_TYPE_AUDIO);
    if (ret < 0) {
        printf("stream_component_open %s faild\n", av_get_media_type_string(AVMEDIA_TYPE_AUDIO));
        return -1;
    }
    ret = stream_component_open(is, AVMEDIA_TYPE_VIDEO);
    if (ret < 0) {
        printf("stream_component_open %s faild\n", av_get_media_type_string(AVMEDIA_TYPE_VIDEO));
        return -1;
    }
    is->fmt_ctx = fmt_ctx;
    /* dump input information to stderr输出音视频信息 */
    //av_dump_format(fmt_ctx, 0, is->src_filename, 0);
    
    int audio_st_idx = is->audio_stream_idx;
    int video_st_idx = is->video_stream_idx;
    /* initialize packet, set data to NULL, let the demuxer fill it */
    is->pkt=av_packet_alloc();
    av_init_packet(is->pkt);
    is->pkt->data = NULL;
    is->pkt->size = 0;
    for (;;) {
        if (is->audioq.size > MAX_AUDIOQ_SIZE ||
            is->videoq.size >  MAX_AUDIOQ_SIZE) {
            av_usleep(10000);
        }
        ret = av_read_frame(is->fmt_ctx, is->pkt);
        if( ret < 0) {
            if (ret == AVERROR_EOF) {
                is->end = 1;
                goto end;
//                break;
            }
            if(is->fmt_ctx->pb->error == 0) {
                av_usleep(1000000);
                /* no error; wait for user input */
                continue;
            } else {
                break;
            }
        }
        
        if (is->pkt->stream_index == audio_st_idx) {
            packet_queue_put(&is->audioq, is->pkt);
        } else if (is->pkt->stream_index == video_st_idx) {
            packet_queue_put(&is->videoq, is->pkt);
        } else {
            printf("other type packt...");
        av_packet_unref(is->pkt);
        }
    }
end:
    while (!is->quit) {
        av_usleep(100000);//0.1s
    }
    return 0;
}

double get_audio_clock(VideoState *is) {
    double pts;
    int hw_buf_size, bytes_per_sec, n;
    
    pts = is->audio_clock; /* 在音频线程维护*/
    hw_buf_size = is->audio_buf_size - is->audio_buf_index;
    bytes_per_sec = 0;
    n = is->audio_ctx->channels * 2;
    if(is->audio_stream) {
        bytes_per_sec = is->audio_ctx->sample_rate * n;
    }
    if(bytes_per_sec) {
        pts -= (double)hw_buf_size / bytes_per_sec;
    }
    return pts;
}

int video_thread(void *data) {
    VideoState *is = (VideoState *)data;
    AVPacket pkt1, *packet = &pkt1;
    AVFrame *pFrame;
    double pts;
    int ret = 0;
    is->pictq_mutex = SDL_CreateMutex();
    is->pictq_cond = SDL_CreateCond();
    AVCodecContext *video_dec_ctx = is->video_ctx;
    pFrame = av_frame_alloc();
    for(;;) {
        if(packet_queue_get(&is->videoq, packet, 1) < 0) {
            break; // means we quit getting packets
        }
        pts = 0;
        
        // Decode video frame
        ret = avcodec_send_packet(video_dec_ctx, packet);
        if (ret != 0) {
            printf("avcodec_send_packet failed.\n");
        }
        ret = avcodec_receive_frame(video_dec_ctx, pFrame);
        switch (ret) {
            case 0:
                while (ret==0) {
                    if((pts = av_frame_get_best_effort_timestamp(pFrame)) == AV_NOPTS_VALUE) {
                        pts = 0;
                    }
                    pts *= av_q2d(is->video_stream->time_base);
                    //同步
                    pts = sysnchronize_video(is, pFrame, pts);
                    //处理 pframe
                    queue_picture(is, pFrame);
                    
                    av_frame_unref(pFrame);
                    ret = avcodec_receive_frame(video_dec_ctx, pFrame);
                }
                av_frame_unref(pFrame);
                break;
            case AVERROR(EAGAIN):
                printf("Resource temporarily unavailable\n");
                break;
            case AVERROR_EOF:
                printf("End of file\n");
                break;
            default:
                printf("other error.. code: %d\n", AVERROR(ret));
                break;
        }
    }
    av_packet_unref(packet);
    return 0;
}

int queue_picture(VideoState *is, AVFrame *pFrame) {
    SDL_LockMutex(is->pictq_mutex);
    while (is->pictq_size >= VIDEO_PICTURE_QUEUE_SIZE && !is->quit) {
        SDL_CondWait(is->pictq_cond, is->pictq_mutex);
    }
    SDL_UnlockMutex(is->pictq_mutex);
    
    if (is->quit) {
        return -1;
    }
    AVFrame *frame = av_frame_alloc();
    av_frame_unref(frame);
    av_frame_move_ref(frame, pFrame);

    SDL_LockMutex(is->pictq_mutex);
    is->pictq[0] = frame;
    is->pictq_size++;
    SDL_UnlockMutex(is->pictq_mutex);
    return 0;
}

double sysnchronize_video(VideoState *is, AVFrame *src_frame, double pts) {
    double frame_delay;
    if (pts != 0) {
        //如果我们有pts，设置视频时钟
        is->video_clock = pts;
    } else {
        //如果我们没有得到pts，把它设置为时钟
        pts = is->video_clock;
    }
    //更新视频时钟
    frame_delay = av_q2d(is->video_stream->time_base);;
    //如果我们重复一帧，相应地调整时钟
    frame_delay += src_frame->repeat_pict * (frame_delay*0.5);
    is->video_clock += frame_delay;
    return pts;
}

//
int video_refresh_timer(void *userdata) {
    
    VideoState *is = (VideoState *)userdata;
    AVFrame *vp;
    double actual_delay, delay, sync_threshold, ref_clock, diff;
    
    if(is->video_stream) {
        if(is->pictq_size == 0) {
            return 1;
//            schedule_refresh(is, 1);
        } else {
            vp = is->pictq[is->pictq_rindex];
            
            delay = vp->pts - is->frame_last_pts; /* the pts from last time */
            if(delay <= 0 || delay >= 1.0) {
                /* if incorrect delay, use previous one */
                delay = is->frame_last_delay;
            }
            /* save for next time */
            is->frame_last_delay = delay;
            is->frame_last_pts = vp->pts;
            
            /* update delay to sync to audio */
            ref_clock = get_audio_clock(is);
            diff = vp->pts - ref_clock;
            
            /* Skip or repeat the frame. Take delay into account
             FFPlay still doesn't "know if this is the best guess." */
            sync_threshold = (delay > AV_SYNC_THRESHOLD) ? delay : AV_SYNC_THRESHOLD;
            if(fabs(diff) < AV_NOSYNC_THRESHOLD) {
                if(diff <= -sync_threshold) {
                    delay = 0;
                } else if(diff >= sync_threshold) {
                    delay = 2 * delay;
                }
            }
            is->frame_timer += delay;
            /* computer the REAL delay */
            actual_delay = is->frame_timer - (av_gettime() / 1000000.0);
            if(actual_delay < 0.010) {
                /* Really it should skip the picture instead */
                actual_delay = 0.010;
            }
            //设置多长时间后显示下一帧
//            schedule_refresh(is, (int)(actual_delay * 1000 + 0.5));
            return  (int)(actual_delay * 1000 + 0.5);
            /* show the picture! */
//            video_display(is);
            
            /* update queue for next picture! */
//            if(++is->pictq_rindex == VIDEO_PICTURE_QUEUE_SIZE) {
//                is->pictq_rindex = 0;
//            }
//            SDL_LockMutex(is->pictq_mutex);
//            is->pictq_size--;
//            SDL_CondSignal(is->pictq_cond);
//            SDL_UnlockMutex(is->pictq_mutex);
        }
    } else {
        return 100;
//        schedule_refresh(is, 100);
    }
}

AVFrame* display_thread(VideoState *is) {
    AVFrame *frame = is->pictq[0];
    while (!frame) {
        usleep(1000*80);
        frame = is->pictq[0];
    }
    SDL_LockMutex(is->pictq_mutex);
    is->pictq_size--;
    SDL_CondSignal(is->pictq_cond);
    SDL_UnlockMutex(is->pictq_mutex);
    
    return frame;
}


int audio_decode_frame(VideoState *is, double *pts_ptr) {
    int data_size = 0;
    AVPacket *pkt = &is->audio_pkt;
    double pts;
    int n;
    int ret = 0;
    AVCodecContext *audio_dec_ctx = is->audio_ctx;
    
    for(;;) {
        while(is->audio_pkt_size > 0) {
            ret = avcodec_send_packet(audio_dec_ctx, pkt);
            if (ret != 0) {
                printf("avcodec_send_packet failed.\n");
            }
            ret = avcodec_receive_frame(audio_dec_ctx, &is->audio_frame);
            switch (ret) {
                case 0:
                    is->audio_pkt_size -= is->audio_frame.pkt_size;
                    data_size = resampleAudioToS16(is);
                    break;
                case AVERROR(EAGAIN):
                    printf("Resource temporarily unavailable\n");
                    break;
                case AVERROR_EOF:
                    printf("End of file\n");
                    break;
                default:
                    printf("other error.. code: %d\n", AVERROR(ret));
                    break;
            }
            if(data_size <= 0) {
                /* No data yet, get more frames */
                continue;
            }
            pts = is->audio_clock;
            *pts_ptr = pts;
            n = 2 * is->audio_ctx->channels;
            is->audio_clock += (double)data_size / (double)(n * is->audio_ctx->sample_rate);
            av_packet_unref(pkt);
            /* We have data, return it and come back for more later */
            return data_size;
        }
        if(pkt->data)
            av_packet_unref(pkt);
        // av_free_packet(pkt);
        if(is->quit) {
            return -1;
        }
        /* next packet */
        if(packet_queue_get(&is->audioq, pkt, 1) < 0) {
            return -1;
        }
        is->audio_pkt_size = pkt->size;
        /* if update, update the audio clock w/pts */
        if(pkt->pts != AV_NOPTS_VALUE) {
            is->audio_clock = av_q2d(is->audio_stream->time_base)*pkt->pts;
        }
    }
}


int resampleAudioToS16(VideoState *is) {
    int ret = 0;
    enum AVSampleFormat des_fmt = AV_SAMPLE_FMT_S16;
    AVFrame *frame = &is->audio_frame;
    if (is->audio_swr_ctx == NULL) {
        //创建并设置参数des: 目标参数, scr:源参数
        is->audio_swr_ctx = swr_alloc_set_opts(NULL,
                                               /*dst**/    frame->channel_layout, des_fmt, frame->sample_rate,
                                               /*src**/    frame->channel_layout, frame->format, frame->sample_rate,
                                               0, NULL);
        swr_init(is->audio_swr_ctx);
        if (!swr_is_initialized(is->audio_swr_ctx)) {
            printf("swr_init failed");
            is->audio_swr_ctx = NULL; return -1;
        }
    }
    //frame->channel_layout(声道布局) 和 AV_CH_LAYOUT_STEREO(单声道还是立体声)类型对应
    //根据声道布局计算出声道数（立体声->2个声道）
    int nb_channels = av_get_channel_layout_nb_channels(frame->channel_layout);
    //获取重采样后数据的size
    int size = av_samples_get_buffer_size(NULL, nb_channels, frame->nb_samples, des_fmt, 0);
    if (size > AVCODEC_MAX_AUDIO_FRAME_SIZE) {
        printf("is->audio_buf is too small to fit content");
        is->audio_buf_size = 0;
        return -1;
    }
    /* compute the number of converted samples: buffering is avoided
     * ensuring that the output buffer will contain at least all the
     * converted input samples */
    int dst_nb_samples = (int)av_rescale_rnd(frame->nb_samples, frame->sample_rate, frame->sample_rate, AV_ROUND_UP);
    //根据目标音频信息申请内存空间
    ret = av_samples_alloc(&is->audioData, NULL, nb_channels, dst_nb_samples, des_fmt, 1);
    if (ret <= 0) { return -1; }
    ret = swr_convert(is->audio_swr_ctx, &is->audioData, dst_nb_samples, (const uint8_t **)frame->data, frame->nb_samples);
    if (ret < 0){ printf("swr_convert error \n"); return -1; }
    is->audio_buf_size = size;
    return size;
}


int audio_paly_callback(uint8_t *data) {
    VideoState *is = global_video_state;
    int audio_size;
    double pts;
    for (;;) {
        audio_size = audio_decode_frame(is, &pts);
        if (audio_size > 0) {
            memcpy(data, is->audioData, is->audio_buf_size);
            free(is->audioData);
            return audio_size;
        } else {
            data = NULL;
            return 0;
        }
    }
}

int start_main(VideoState *is, void *(*videoCallBack)(void *)) {
    is->parse_tid = SDL_CreateThread(decode_thread, is);
    usleep(1000 * 100);//100ms
    for (;;) {
        AVFrame *frame = display_thread(is);
        if (frame) {
            videoCallBack(frame);
            av_frame_unref(frame);
//            if (frame != NULL) {
//                av_frame_free(&frame);
//            }
        }
        usleep(1000 * 80);//80ms
//        int sleep = video_refresh_timer(is);
//        usleep(sleep * 1000);
    }
    
    return 0;
}

