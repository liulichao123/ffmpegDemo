//
//  PlayerVC.h
//  ffmpegDemo
//
//  Created by 天明 on 2017/11/30.
//  Copyright © 2017年 天明. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OpenGLView20.h"
@interface PlayerVC : NSObject
@property (nonatomic, strong) OpenGLView20 *glView;
- (instancetype)initWithFile:(NSString *)path;
- (void)start;
@end
