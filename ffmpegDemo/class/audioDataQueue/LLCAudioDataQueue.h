//
//  LLCAudioDataQueue.h
//  AudioQueue使用me
//
//  Created by mac on 16/9/13.
//  Copyright © 2016年 刘立超. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
@interface LLCAudioDataQueue : NSObject
/**
 *  用于记录录音的采集信息，供播放时使用
 */
@property (nonatomic, assign) AudioStreamBasicDescription outAudioStreamBasicDescription;
@property (nonatomic, readonly) int count;

+(instancetype) shareInstance;

- (void)addData:(id)obj;

- (id)getData;
@end
