//
//  ffplayer_decoder.h
//  ffmpegDemo
//
//  Created by 天明 on 2017/11/30.
//  Copyright © 2017年 天明. All rights reserved.
//

#ifndef ffplayer_decoder_h
#define ffplayer_decoder_h
#include <stdio.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#import <libswresample/swresample.h>
#include <libswscale/swscale.h>
#import <libavutil/time.h>
#include "SDL_Thread.h"
// compatibility with newer API
#if LIBAVCODEC_VERSION_INT < AV_VERSION_INT(55,28,1)
#define av_frame_alloc avcodec_alloc_frame
#define av_frame_free avcodec_free_frame
#endif

#define SDL_AUDIO_BUFFER_SIZE 1024
#define MAX_AUDIO_FRAME_SIZE 192000

#define MAX_AUDIOQ_SIZE (300)
#define MAX_VIDEOQ_SIZE (30)

#define AV_SYNC_THRESHOLD 0.01
#define AV_NOSYNC_THRESHOLD 10.0

#define FF_REFRESH_EVENT (SDL_USEREVENT)
#define FF_QUIT_EVENT (SDL_USEREVENT + 1)

#define VIDEO_PICTURE_QUEUE_SIZE 1

#define AVCODEC_MAX_AUDIO_FRAME_SIZE 6144 //4096*1.5

typedef struct PacketQueue {
    AVPacketList *first_pkt, *last_pkt;
    int nb_packets;
    int size;
    SDL_mutex *mutex;
    SDL_cond *cond;
} PacketQueue;

typedef struct VideoState {
    SDL_Thread      *parse_tid;
    
    AVFormatContext *fmt_ctx;
    AVPacket        *pkt;
    
    // audio
    AVCodecContext  *audio_ctx;
    AVCodec         *audio_code;
    AVStream        *audio_stream;
    int             audio_stream_idx;
    AVFrame         audio_frame;
    AVPacket        audio_pkt;
    struct SwrContext *audio_swr_ctx;
    PacketQueue     audioq;
    uint8_t         audio_buf[AVCODEC_MAX_AUDIO_FRAME_SIZE];
    uint8_t         *audioData;
    unsigned int    audio_buf_size;
    unsigned int    audio_buf_index;
    uint8_t         *audio_pkt_data;
    int             audio_pkt_size;
    int             audio_hw_buf_size;
    double          audio_clock;
    
    
    //video
    AVCodec         *video_code;
    AVCodecContext  *video_ctx;
    AVStream        *video_stream;
    int             video_stream_idx;
    struct SwsContext *vodeo_sws_ctx;
    PacketQueue     videoq;
    AVFrame         *pictq[VIDEO_PICTURE_QUEUE_SIZE];
    double          frame_timer;
    double          frame_last_pts;
    double          frame_last_delay;
    double          video_clock;
    int             pictq_size, pictq_rindex, pictq_windex;
    SDL_mutex       *pictq_mutex;
    SDL_cond        *pictq_cond;
    SDL_Thread      *video_tid;
    int             video_next_delay;
    
    char            filename[1024];
    const char      *src_filename;
    
    int             quit;
    int             end;
} VideoState;


void packet_queue_init(PacketQueue *q);
int packet_queue_put(PacketQueue *q, AVPacket *pkt);
int packet_queue_get(PacketQueue *q, AVPacket *pkt, int block);
int stream_component_open(VideoState *is, enum AVMediaType type);
int decode_thread(void *data);

int audio_decode_frame(VideoState *is, double *pts_ptr);
int resampleAudioToS16(VideoState *is);
int audio_paly_callback(uint8_t *data);

int video_thread(void *data);
int queue_picture(VideoState *is, AVFrame *pFrame);
double sysnchronize_video(VideoState *is, AVFrame *src_frame, double pts);
AVFrame* display_thread(VideoState *is);

int start_main(VideoState *is, void *(*videoCallBack)(void *));

#endif /* ffplayer_decoder_h */
