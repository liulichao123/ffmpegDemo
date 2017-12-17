//
//  FFPlayer.m
//  ffmpegDemo
//
//  Created by 天明 on 2017/11/26.
//  Copyright © 2017年 天明. All rights reserved.
//

#import "FFPlayer.h"
#import "ffplayer_decoder.h"

@interface FFPlayer ()
@property (nonatomic, strong) dispatch_queue_t queue1;
@property (nonatomic, strong) dispatch_queue_t queue2;
@property (nonatomic, strong) dispatch_queue_t queue3;
@property (nonatomic, assign) VideoState *is;
@end
@implementation FFPlayer
OpenGLView20 *glView;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _queue1 = dispatch_queue_create("__ffmpeg_decoder_queue1__", NULL);
        _queue2 = dispatch_queue_create("__ffmpeg_decoder_queue2__", NULL);
        _queue3 = dispatch_queue_create("__ffmpeg_decoder_queue3__", NULL);
        _is = av_mallocz(sizeof(VideoState));
        av_register_all();
    }
    return self;
}

- (void)startWithFile:(NSString *)path {
    glView = _glView;
    _is->src_filename = [path UTF8String];
    dispatch_async(_queue1, ^{
        start_main(_is, videoCallBack);
    });
}

void* videoCallBack(void *data) {
    AVFrame *frame = (AVFrame *)data;
    if (frame) {
        [glView displayYUV420pData:frame];
//        av_frame_unref(frame);
    }
    return NULL;
}






@end

///**
// 解码音视频文件
// @param file 文件路径
// */
//- (void)decodeAudioAndVideoFile:(NSString *)file {
//    const char *src_filename = [file UTF8String];
//    //打开文件
//    ret = avformat_open_input(&fmt_ctx, src_filename, NULL, NULL);
//    if (ret < 0) {
//        printf("Could not open source file\n");
//        return;
//    }
//    //找到流信息
//    ret = avformat_find_stream_info(fmt_ctx, 0);
//    if (ret < 0) {
//        printf("Could not find stream information\n");
//        return;
//    }
//    //找到音频和视频流的 index,
//    video_stream_idx = av_find_best_stream(fmt_ctx, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
//    audio_stream_idx = av_find_best_stream(fmt_ctx, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0);
//    if (video_stream_idx < 0) {
//        printf("Could not find %s stream in input file\n", av_get_media_type_string(AVMEDIA_TYPE_VIDEO));
//        return;
//    }
//    //根据index找到对应的stream
//    video_stream = fmt_ctx->streams[video_stream_idx];
//    if (!video_stream) {
//        printf("Could not find video stream in the input, aborting\n");
//        return;
//    }
//    if (audio_stream_idx < 0) {
//        printf("Could not find %s stream in input file\n", av_get_media_type_string(AVMEDIA_TYPE_AUDIO));
//        return;
//    }
//    audio_stream = fmt_ctx->streams[audio_stream_idx];
//    if (!audio_stream) {
//        printf("Could not find audio stream in the input, aborting\n");
//        return;
//    }
//
//    /* find decoder for the stream */
//    video_code = avcodec_find_decoder(video_stream->codecpar->codec_id);
//    if (!video_code) {
//        printf("Failed to find %s codec\n", av_get_media_type_string(AVMEDIA_TYPE_VIDEO));
//        return;
//    }
//    /* Allocate a codec context for the decoder */
//    video_dec_ctx = avcodec_alloc_context3(video_code);
//    if (!video_dec_ctx) {
//        printf("Failed to allocate the %s codec context\n", av_get_media_type_string(AVMEDIA_TYPE_VIDEO));
//        return;
//    }
//    audio_code = avcodec_find_decoder(audio_stream->codecpar->codec_id);
//    if (!audio_code) {
//        printf("Failed to find %s codec\n", av_get_media_type_string(AVMEDIA_TYPE_AUDIO));
//        return;
//    }
//    audio_dec_ctx = avcodec_alloc_context3(audio_code);
//    if (!audio_dec_ctx) {
//        printf("Failed to allocate the %s codec context\n", av_get_media_type_string(AVMEDIA_TYPE_AUDIO));
//        return;
//    }
//
//    /* Copy codec parameters from input stream to output codec context */
//    if ((ret = avcodec_parameters_to_context(video_dec_ctx, video_stream->codecpar)) < 0) {
//        printf("Failed to copy %s codec parameters to decoder context\n", av_get_media_type_string(AVMEDIA_TYPE_VIDEO));
//        return;
//    }
//    if ((ret = avcodec_parameters_to_context(audio_dec_ctx, audio_stream->codecpar)) < 0) {
//        printf("Failed to copy %s codec parameters to decoder context\n", av_get_media_type_string(AVMEDIA_TYPE_AUDIO));
//        return;
//    }
//
//    static int refcount = 0;
//    /* Init the decoders, with or without reference counting */
//    av_dict_set(&opts, "refcounted_frames", refcount ? "1" : "0", 0);
//    if ((ret = avcodec_open2(video_dec_ctx, video_code, &opts)) < 0) {
//        printf("Failed to open %s codec\n", av_get_media_type_string(AVMEDIA_TYPE_VIDEO));
//        return;
//    }
//    if ((ret = avcodec_open2(audio_dec_ctx, audio_code, &opts)) < 0) {
//        printf("Failed to open %s codec\n", av_get_media_type_string(AVMEDIA_TYPE_AUDIO));
//        return;
//    }
//
//    /* dump input information to stderr输出音视频信息 */
//    av_dump_format(fmt_ctx, 0, src_filename, 0);
//
//
//
//    //释放空间
//    av_frame_free(&video_frame);
//    av_frame_free(&audio_frame);
//    avformat_close_input(&fmt_ctx);
//    printf("结束\n");
//}

//
////解码视频
//- (void)decodeVideo {
//    ret = avcodec_send_packet(video_dec_ctx, pkt);
//    if (ret != 0) {
//        printf("avcodec_send_packet failed.\n");
//    }
//    ret = avcodec_receive_frame(video_dec_ctx, video_frame);
//    switch (ret) {
//        case 0:
//            while (ret==0) {
//                [self handleDecodedVideoFrame:video_frame];
//                av_frame_unref(video_frame);
//                ret = avcodec_receive_frame(video_dec_ctx, video_frame);
//            }
//            break;
//        case AVERROR(EAGAIN):
//            printf("Resource temporarily unavailable\n");
//            break;
//        case AVERROR_EOF:
//            printf("End of file\n");
//            break;
//        default:
//            printf("other error.. code: %d\n", AVERROR(ret));
//            break;
//    }
//}
////解码音频
//- (void)decodeAudio {
//    ret = avcodec_send_packet(audio_dec_ctx, pkt);
//    if (ret != 0) {
//        printf("avcodec_send_packet failed.\n");
//    }
//    ret = avcodec_receive_frame(audio_dec_ctx, audio_frame);
//    switch (ret) {
//        case 0:
//            while (ret==0) {
//                NSData *data = [self handleDecodedAudioFrame:audio_frame];
//                av_frame_unref(audio_frame);
//                ret = avcodec_receive_frame(audio_dec_ctx, audio_frame);
//            }
//            break;
//        case AVERROR(EAGAIN):
//            printf("Resource temporarily unavailable\n");
//            break;
//        case AVERROR_EOF:
//            printf("End of file\n");
//            break;
//        default:
//            printf("other error.. code: %d\n", AVERROR(ret));
//            break;
//    }
//}
////处理解码后的视频frame
//- (void)handleDecodedVideoFrame:(AVFrame *)frame {
//
//}
//
////处理解码后的音频frame
//- (NSData *)handleDecodedAudioFrame:(AVFrame *)frame {
//    if (frame->format != AV_SAMPLE_FMT_S16) {
//        return [self resampleAudioToS16:frame];
//    } else {
//        if (frame->linesize[0]) {
//            return [NSData dataWithBytes:frame->data[0] length:frame->linesize[0]];
//        } else {
//            return nil;
//        }
//    }
//}
//
////音频重采样 方法一
//- (NSData *)resampleAudioToS16:(AVFrame *)frame {
//    int ret = 0;
//    enum AVSampleFormat des_fmt = AV_SAMPLE_FMT_S16;
//    if (swr == NULL) {
//        //创建并设置参数des: 目标参数, scr:源参数
//        swr = swr_alloc_set_opts(NULL,
//                                 /*dst**/    frame->channel_layout, des_fmt, frame->sample_rate,
//                                 /*src**/    frame->channel_layout, frame->format, frame->sample_rate,
//                                 0, NULL);
//        swr_init(swr);
//        if (!swr_is_initialized(swr)) {
//            printf("swr_init failed");
//            swr = NULL; return nil;
//        }
//    }
//    uint8_t *dstData = NULL;
//    /* compute the number of converted samples: buffering is avoided
//     * ensuring that the output buffer will contain at least all the
//     * converted input samples */
//    int dst_nb_samples = (int)av_rescale_rnd(frame->nb_samples, frame->sample_rate, frame->sample_rate, AV_ROUND_UP);
//    //frame->channel_layout(声道布局) 和 AV_CH_LAYOUT_STEREO(单声道还是立体声)类型对应
//    //根据声道布局计算出声道数（立体声=>2个声道）
//    int nb_channels = av_get_channel_layout_nb_channels(frame->channel_layout);
//    //根据目标音频信息申请内存空间
//    ret = av_samples_alloc(&dstData, NULL, nb_channels, dst_nb_samples, des_fmt, 1);
//    if (ret <= 0) { return nil; }
//    //转换
//    ret = swr_convert(swr, &dstData, dst_nb_samples, (const uint8_t **)frame->data, frame->nb_samples);
//    //ret = swr_convert(swr, &dstData, dst_nb_samples, (const uint8_t **)frame->extended_data, frame->nb_samples); 等价于上面frame->extended_data即指向frame->data数组
//    if (ret < 0){ printf("swr_convert error \n"); return nil; }
//    //获取重采样后数据的size
//    int size = av_samples_get_buffer_size(NULL, nb_channels, frame->nb_samples, des_fmt, 0);
//    NSData *data = [NSData dataWithBytes:dstData length:size];
//    if (dstData) {
//        av_freep(&dstData);
//    }
//    return data;
//}
//
////音频重采样 方法二
//- (NSData *)resampleAudioToS16_1:(AVFrame *)frame {
//    int ret = 0;
//    enum AVSampleFormat des_fmt = AV_SAMPLE_FMT_S16;
//    if (swr == NULL) {
//        swr = swr_alloc_set_opts(NULL,
//                                 /*dst**/    frame->channel_layout, des_fmt, frame->sample_rate,
//                                 /*src**/    frame->channel_layout, frame->format, frame->sample_rate,
//                                 0, NULL);
//        swr_init(swr);
//        if (!swr_is_initialized(swr)) {
//            printf("swr_init failed");
//            swr = NULL; return nil;
//        }
//    }
//    //能够兼容目标格式是plane类型的转换(dstData[0],dstData[1]...)，转换成非plane时，数据在都dstData[0]中
//    uint8_t **dstData = NULL;
//    /* compute the number of converted samples: buffering is avoided
//     * ensuring that the output buffer will contain at least all the
//     * converted input samples */
//    int dst_nb_samples = (int)av_rescale_rnd(frame->nb_samples, frame->sample_rate, frame->sample_rate, AV_ROUND_UP);
//    int channels = av_get_channel_layout_nb_channels(frame->channel_layout);
//    //申请一个数组空间，可以存放plane类型
//    ret = av_samples_alloc_array_and_samples(&dstData, NULL, channels, dst_nb_samples, des_fmt, 1);
//    if (ret <= 0) { return nil; }
//    ret = swr_convert(swr, dstData, dst_nb_samples, (const uint8_t **)frame->data, frame->nb_samples);
//    //ret = swr_convert(swr, dstData, dst_nb_samples, (const uint8_t **)frame->extended_data, frame->nb_samples);等价于上面frame->extended_data即指向frame->data数组
//    if (ret < 0){ printf("swr_convert error \n"); return nil; }
//    //获取重采样后数据的size
//    int size = av_samples_get_buffer_size(NULL, channels, frame->nb_samples, des_fmt, 0);
//    NSData *data = [NSData dataWithBytes:dstData[0] length:size];
//    if (dstData) {
//        av_freep(&dstData[0]);
//    }
//    return data;
//}
//
//
////音频重采样 方法三
//- (NSData *)converFrame: (AVFrame *)frame {
//    int ret = 0;
//    AVFrame *desFrame = av_frame_alloc();
//    //需设置好目标frame参数
//    desFrame->format = AV_SAMPLE_FMT_S16;
//    desFrame->channel_layout = frame->channel_layout;
//    desFrame->sample_rate = frame->sample_rate;
//    desFrame->nb_samples = frame->nb_samples;
//    if (swr == NULL) {
//        swr = swr_alloc_set_opts(NULL,
//                                 /*dst**/    desFrame->channel_layout, desFrame->format, desFrame->sample_rate,
//                                 /*src**/    frame->channel_layout, frame->format, frame->sample_rate,
//                                 0, NULL);
//        swr_init(swr);
//        if (!swr_is_initialized(swr)) {
//            printf("swr_init failed");
//            swr = NULL; return nil;
//        }
//    }
//    ret = swr_convert_frame(swr, desFrame, frame);
//    if (ret > 0) {
//        //计算转换后数据大小，不能直接使用desFrame->linesize[0],它是不准确的
//        int des_channels = av_get_channel_layout_nb_channels(desFrame->channel_layout);
//        int dse_size = av_samples_get_buffer_size(NULL, des_channels, desFrame->nb_samples, desFrame->format, 0);
//        NSData *data = [NSData dataWithBytes:desFrame->data[0] length:dse_size];
//        return data;
//    }
//    return nil;
//}

