//
//  PlayerVC.m
//  ffmpegDemo
//
//  Created by 天明 on 2017/11/30.
//  Copyright © 2017年 天明. All rights reserved.
//

#import "PlayerVC.h"
#import "FFPlayer.h"
#import "TMAudioPCMPlayer.h"
#import "TMAVConfig.h"

@interface PlayerVC ()

@end

@implementation PlayerVC {
    FFPlayer *ffp;
    TMAudioPCMPlayer *aPlayer;
    NSString *filePath;
}

- (instancetype)initWithFile:(NSString *)path
{
    self = [super init];
    if (self) {
        ffp = [[FFPlayer alloc] init];
        aPlayer = [[TMAudioPCMPlayer alloc] initWithConfig:[TMAudioConfig defaultConifg]];
        filePath = path;
        _glView = [[OpenGLView20 alloc] initWithFrame:CGRectMake(70, 100, 240, 320)];
        ffp.glView = _glView;
    }
    return self;
}

- (void)start {
    [ffp startWithFile:filePath];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [aPlayer start];
    });
    
}


@end
