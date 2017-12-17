//
//  FFPlayer.h
//  ffmpegDemo
//
//  Created by 天明 on 2017/11/26.
//  Copyright © 2017年 天明. All rights reserved.
//  需要互斥锁

#import <Foundation/Foundation.h>
#import "OpenGLView20.h"
@interface FFPlayer : NSObject
@property (nonatomic, strong) OpenGLView20 *glView;
- (void)startWithFile:(NSString *)path;
@end
