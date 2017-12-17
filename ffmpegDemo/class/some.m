//
//  some.m
//  ffmpegDemo
//
//  Created by 天明 on 2017/11/30.
//  Copyright © 2017年 天明. All rights reserved.
//

#import "some.h"

@implementation some
//int decodeAudio() {
//
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
@end
