//
//  ViewController.m
//  ffmpegDemo
//
//  Created by 天明 on 2017/9/19.
//  Copyright © 2017年 天明. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "ViewController.h"
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#import <libswresample/swresample.h>
#import <libavutil/time.h>


#import "AAPLEAGLLayer.h"
#import "OpenGLView20.h"
#import "TMAudioPCMPlayer.h"
#import "TMAVConfig.h"
#import "LLCAudioDataQueue.h"
#import "PlayerVC.h"

/* no AV sync correction is done if below the minimum AV sync threshold */
#define AV_SYNC_THRESHOLD_MIN 0.04
/* AV sync correction is done if above the maximum AV sync threshold */
#define AV_SYNC_THRESHOLD_MAX 0.1
/* If a frame duration is longer than this, it will not be duplicated to compensate AV sync */
#define AV_SYNC_FRAMEDUP_THRESHOLD 0.1
/* no AV correction is done if too big error */
#define AV_NOSYNC_THRESHOLD 10.0

#define AV_SYNC_THRESHOLD  0.01

@interface ViewController ()
@property (nonatomic, strong) AAPLEAGLLayer *displayLayer;
@property (nonatomic, strong) OpenGLView20 *glView;
@property (nonatomic, strong) TMAudioPCMPlayer *player;
@property (nonatomic, strong) PlayerVC *playerVC;

@end

@implementation ViewController {
    dispatch_queue_t queue;
    dispatch_queue_t audioPlayerQueue;
    SwrContext *swr;
    AVStream *video_stream;
    AVStream *audio_stream;

}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *fileName = [[NSBundle mainBundle] pathForResource:@"test.mp4" ofType:nil];
    _playerVC = [[PlayerVC alloc] initWithFile:fileName];
    [self.view addSubview:_playerVC.glView];
    [_playerVC start];
}

- (void)test1{
    _glView = [[OpenGLView20 alloc] initWithFrame:CGRectMake(70, 100, 240, 320)];
    [self.view addSubview:_glView];
    _player = [[TMAudioPCMPlayer alloc] initWithConfig:[TMAudioConfig defaultConifg]];
    queue = dispatch_queue_create("queue", NULL);
    audioPlayerQueue = dispatch_queue_create("atuioPlayerQueue", NULL);
    dispatch_async(queue, ^{
        NSLog(@"开始解码");
        [self test];
    });
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [_player start];
}



- (void)handleDecodeVideoFrame:(AVFrame *)frame {
    //av_q2d(video_stream->time_base) 这样计算出1个时间单位，它的时间体系和我们用的不太一样，需要转换
    //计算总时长 秒
//    double_t totalTimeLenth = video_stream->duration * av_q2d(video_stream->time_base);
//    //计算应该在第多少秒显示
//    double_t frameShowAtTime = frame->pts * av_q2d(video_stream->time_base);
//    printf("%f, %f\n", totalTimeLenth, frameShowAtTime);
//    printf("%lld, %lld, %lld\n", frame->pkt_duration, frame->pkt_dts, frame->pts);
//
    
//    if (delay < 0 || delay > 1) {
//        delay = last_video_delay;
//    }
//    last_video_delay = delay;
//    last_video_pts = current_video_pts;
//
//    //根据Audio clock来判断Video播放的快慢
//    //diff<0: video slow, diff>0: video quick
//    double diff = audio_clock - current_video_pts;
//    //同步阈值
//    double threshold = (delay > AV_SYNC_THRESHOLD) ? delay : AV_SYNC_THRESHOLD;
//    if (fabs(diff) < AV_NOSYNC_THRESHOLD) {
//        if (diff < -threshold) { //慢了，delay设为0
//            delay = 0;
//        } else if (diff >= threshold) { //快了，加倍delay
//            delay *= 2;
//        }
//    }
//    video_delay_timer += delay;
//    double actual_delay = video_delay_timer - (av_gettime() / 1000000.0);
//    if (actual_delay <= 0.010)
//        actual_delay = 0.010;
//
    
    [_glView displayYUV420pData:frame];
}

- (void)handleDecodeAudioFrame:(AVFrame *)frame {
    
    if (av_sample_fmt_is_planar(frame->format) || frame->format != AV_SAMPLE_FMT_S16) {
//        int a = av_get_bytes_per_sample(frame->format);
//        int perPlaneSize = av_get_bytes_per_sample(frame->format)*frame->nb_samples;
//        frame->linesize[0] 正好等于 perPlaneSize * frame->channels;
        enum AVSampleFormat des_fmt = AV_SAMPLE_FMT_S16;
        int ret = 0;
        if (swr == NULL) {
            swr = swr_alloc_set_opts(NULL,
                        /*dst**/    frame->channel_layout, des_fmt, frame->sample_rate,
                        /*src**/    frame->channel_layout, frame->format, frame->sample_rate,
                                     0, NULL);
            swr_init(swr);
            if (!swr_is_initialized(swr)) {
                printf("swr_init failed");
                swr = NULL; return;
            }
        }
//        //直接转换frame
//        AVFrame *desFrame = av_frame_alloc();
//        desFrame->channel_layout = frame->channel_layout;
//        desFrame->sample_rate = frame->sample_rate;
//        desFrame->format = AV_SAMPLE_FMT_S16;
//        desFrame->nb_samples = frame->nb_samples;
//        ret = swr_convert_frame(swr, desFrame, frame);
//        int des_channels = av_get_channel_layout_nb_channels(desFrame->channel_layout);
//        int dse_size = av_samples_get_buffer_size(NULL, des_channels, desFrame->nb_samples, des_fmt, 0);
//        NSData *data1 = [NSData dataWithBytes:desFrame->data[0] length:dse_size];
//        av_frame_free(&desFrame);
//        [[LLCAudioDataQueue shareInstance] addData:data1];
//        return;
        
        /* compute the number of converted samples: buffering is avoided
         * ensuring that the output buffer will contain at least all the
         * converted input samples */
        int dst_nb_samples = (int)av_rescale_rnd(frame->nb_samples, frame->sample_rate, frame->sample_rate, AV_ROUND_UP);
       //frame->channel_layout(声道布局) 和 AV_CH_LAYOUT_STEREO(单声道还是立体声) 对应
        //根据声道布局计算出声道数
        int channels = av_get_channel_layout_nb_channels(frame->channel_layout);
        uint8_t *dstData = NULL;
        ret = av_samples_alloc(&dstData, NULL, channels, frame->sample_rate, AV_SAMPLE_FMT_S16, 0);
        if (ret <= 0) { return; }
        ret = swr_convert(swr, &dstData, dst_nb_samples, (const uint8_t **)frame->extended_data, frame->nb_samples);
        if (ret < 0){ printf("swr_convert error \n"); return; }
        //计算数据大小
        int size = av_samples_get_buffer_size(NULL, channels, frame->nb_samples, AV_SAMPLE_FMT_S16, 0);
        
        NSData *data = [NSData dataWithBytes:dstData length:size];
        [[LLCAudioDataQueue shareInstance] addData:data];
        if (dstData) {
            av_freep(&dstData);
        }
    } else {
    }
}


- (void)test {
    NSString *fileName = [[NSBundle mainBundle] pathForResource:@"test.mp4" ofType:nil];
    const char *src_filename = [fileName UTF8String];
    AVFormatContext *fmt_ctx = NULL;
    AVPacket *pkt = NULL;
    AVFrame *video_frame = NULL;
    AVFrame *audio_frame = NULL;
    int ret;
    int video_stream_idx;
    int audio_stream_idx;
    AVCodec *video_code = NULL;
    AVCodec *audio_code = NULL;

    AVCodecContext *video_dec_ctx = NULL;
    AVCodecContext *audio_dec_ctx = NULL;
    AVDictionary *opts = NULL;
    
    av_register_all();
    
    ret = avformat_open_input(&fmt_ctx, src_filename, NULL, NULL);
    if (ret < 0) {
        printf("Could not open source file\n");
        return;
    }
    ret = avformat_find_stream_info(fmt_ctx, 0);
    if (ret < 0) {
        printf("Could not find stream information\n");
        return;
    }
    
    video_stream_idx = av_find_best_stream(fmt_ctx, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    audio_stream_idx = av_find_best_stream(fmt_ctx, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0);
    if (video_stream_idx < 0) {
        printf("Could not find %s stream in input file\n", av_get_media_type_string(AVMEDIA_TYPE_VIDEO));
        return;
    }
    video_stream = fmt_ctx->streams[video_stream_idx];
    if (!video_stream) {
        printf("Could not find video stream in the input, aborting\n");
        return;
    }
    if (audio_stream_idx < 0) {
        printf("Could not find %s stream in input file\n", av_get_media_type_string(AVMEDIA_TYPE_AUDIO));
        return;
    }
    audio_stream = fmt_ctx->streams[audio_stream_idx];
    if (!audio_stream) {
        printf("Could not find audio stream in the input, aborting\n");
        return;
    }
    
    /* find decoder for the stream */
    video_code = avcodec_find_decoder(video_stream->codecpar->codec_id);
    if (!video_code) {
        printf("Failed to find %s codec\n", av_get_media_type_string(AVMEDIA_TYPE_VIDEO));
        return;
    }
    /* Allocate a codec context for the decoder */
    video_dec_ctx = avcodec_alloc_context3(video_code);
    if (!video_dec_ctx) {
        printf("Failed to allocate the %s codec context\n", av_get_media_type_string(AVMEDIA_TYPE_VIDEO));
        return;
    }
    
    audio_code = avcodec_find_decoder(audio_stream->codecpar->codec_id);
    if (!audio_code) {
        printf("Failed to find %s codec\n", av_get_media_type_string(AVMEDIA_TYPE_AUDIO));
        return;
    }
    audio_dec_ctx = avcodec_alloc_context3(audio_code);
    if (!audio_dec_ctx) {
        printf("Failed to allocate the %s codec context\n", av_get_media_type_string(AVMEDIA_TYPE_AUDIO));
        return;
    }
    
    /* Copy codec parameters from input stream to output codec context */
    if ((ret = avcodec_parameters_to_context(video_dec_ctx, video_stream->codecpar)) < 0) {
        printf("Failed to copy %s codec parameters to decoder context\n", av_get_media_type_string(AVMEDIA_TYPE_VIDEO));
        return;
    }
    if ((ret = avcodec_parameters_to_context(audio_dec_ctx, audio_stream->codecpar)) < 0) {
        printf("Failed to copy %s codec parameters to decoder context\n", av_get_media_type_string(AVMEDIA_TYPE_AUDIO));
        return;
    }
    
    static int refcount = 0;
    /* Init the decoders, with or without reference counting */
    av_dict_set(&opts, "refcounted_frames", refcount ? "1" : "0", 0);
    if ((ret = avcodec_open2(video_dec_ctx, video_code, &opts)) < 0) {
        printf("Failed to open %s codec\n", av_get_media_type_string(AVMEDIA_TYPE_VIDEO));
        return;
    }
    if ((ret = avcodec_open2(audio_dec_ctx, audio_code, &opts)) < 0) {
        printf("Failed to open %s codec\n", av_get_media_type_string(AVMEDIA_TYPE_AUDIO));
        return;
    }

    /* dump input information to stderr */
    av_dump_format(fmt_ctx, 0, src_filename, 0);
    
    video_frame = av_frame_alloc();
    if (!video_frame) {
        printf("Could not allocate frame\n");
        return;
    }
//    ret = av_frame_get_buffer(video_frame, 1);手动申请内存编码时使用
    audio_frame = av_frame_alloc();
    
    /* initialize packet, set data to NULL, let the demuxer fill it */
    pkt=av_packet_alloc();
    av_init_packet(pkt);
    pkt->data = NULL;
    pkt->size = 0;
    
    /* read frames from the file */
    while (av_read_frame(fmt_ctx, pkt) == 0) {
        if (pkt->stream_index == audio_stream_idx) {
            ret = avcodec_send_packet(audio_dec_ctx, pkt);
            if (ret != 0) {
                printf("avcodec_send_packet failed.\n");
            }
            ret = avcodec_receive_frame(audio_dec_ctx, audio_frame);
            switch (ret) {
                case 0:
                    while (ret==0) {
                        [self handleDecodeAudioFrame:audio_frame];
                        av_frame_unref(audio_frame);
                        ret = avcodec_receive_frame(audio_dec_ctx, audio_frame);
                    }
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
        } else if (pkt->stream_index == video_stream_idx) {
            ret = avcodec_send_packet(video_dec_ctx, pkt);
            if (ret != 0) {
                printf("avcodec_send_packet failed.\n");
            }
            ret = avcodec_receive_frame(video_dec_ctx, video_frame);      
            switch (ret) {
                case 0:
                    while (ret==0) {
                        [self handleDecodeVideoFrame:video_frame];
                        av_frame_unref(video_frame);
                        ret = avcodec_receive_frame(video_dec_ctx, video_frame);
                    }
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
        } else {
            printf("other type packt...");
        }
        av_packet_unref(pkt);
    }
    avcodec_send_packet(video_dec_ctx, NULL);
    while (avcodec_receive_frame(video_dec_ctx, video_frame) == 0) {
        [self handleDecodeVideoFrame:video_frame];
        av_frame_unref(video_frame);
    }
    avcodec_send_packet(audio_dec_ctx, NULL);
    while (avcodec_receive_frame(audio_dec_ctx, audio_frame) == 0) {
        [self handleDecodeAudioFrame:audio_frame];
        av_frame_unref(audio_frame);
    }
    
    if (swr) {
        swr_free(&swr);
    }
    av_frame_free(&video_frame);
    av_frame_free(&audio_frame);
    avformat_close_input(&fmt_ctx);
    NSLog(@"结束");
}






/**
 1、发送NULL到avcodec_send_packet（）（解码）或avcodec_send_frame（）（编码）函数，而不是有效的输入。 这将进入排水模式。
 2、在循环中调用avcodec_receive_frame（）（解码）或avcodec_receive_packet（）（编码），直到返回AVERROR_EOF。 除非您忘记进入排水模式，否则这些功能将不会返回AVERROR（EAGAIN）。
 3、在再次解码之前，必须使用avcodec_flush_buffers（）重新编码。 无需调用！！！！
 */
@end
