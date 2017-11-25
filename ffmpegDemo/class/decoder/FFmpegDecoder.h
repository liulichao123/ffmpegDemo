//
//  FFmpegDecoder.h
//  ffmpegDemo
//
//  Created by 天明 on 2017/11/23.
//  Copyright © 2017年 天明. All rights reserved.
//  ffmepg 解码实例

#import <Foundation/Foundation.h>

@interface FFmpegDecoder : NSObject
- (void)decodeAVFile:(NSString *)path;
@end
