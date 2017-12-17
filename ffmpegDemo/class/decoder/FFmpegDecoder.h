//
//  FFmpegDecoder.h
//  ffmpegDemo
//
//  Created by 天明 on 2017/11/23.
//  Copyright © 2017年 天明. All rights reserved.
//  ffmepg 解码实例

#import <Foundation/Foundation.h>
#import <libavcodec/avcodec.h>
@protocol FFmpegDecoderDelegate
- (void)recivedDecodedVideoFrame: (AVFrame *)frame;
- (void)recivedDecodedAudioFrame: (AVFrame *)frame;
@end

@interface FFmpegDecoder : NSObject
@property (nonatomic, strong) id<FFmpegDecoderDelegate> delegate;
- (void)decodeAVFile:(NSString *)path;
@end
