//
//  NSUserDefaultsUnit.m
//  EasyPlayer
//
//  Created by liyy on 2017/12/30.
//  Copyright © 2017年 cs. All rights reserved.
//

#import "NSUserDefaultsUnit.h"

static NSString *videoUrlPath = @"videoUrls";
static NSString *audioPath = @"audioPath";
static NSString *recordPath = @"recordPath";
static NSString *ffmpegPath = @"ffmpegPath";
static NSString *udpPath = @"udpPath";

@implementation NSUserDefaultsUnit

#pragma mark - 播放url的存储

// 获取所有url
+ (NSMutableArray *) urls {
    NSMutableArray *urls = [[NSUserDefaults standardUserDefaults] objectForKey:videoUrlPath];
    
    return urls;
}

// 添加/删除url
+ (void) updateURL:(NSMutableArray *)urls {
    [[NSUserDefaults standardUserDefaults] setObject:urls forKey:videoUrlPath];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - 开启自动播放音频

+ (void) setAutoAudio:(BOOL)isAudio {
    [[NSUserDefaults standardUserDefaults] setBool:isAudio forKey:audioPath];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL) isAutoAudio {
    return [[NSUserDefaults standardUserDefaults] boolForKey:audioPath];
}

#pragma mark - 开启视频的同时是否进行录像

+ (void) setAutoRecord:(BOOL)isRecord {
    [[NSUserDefaults standardUserDefaults] setBool:isRecord forKey:recordPath];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL) isAutoRecord {
    return [[NSUserDefaults standardUserDefaults] boolForKey:recordPath];
}

#pragma mark - 是否使用FFMpeg进行视频软解码

+ (void) setFFMpeg:(BOOL)isFFMpeg {
    [[NSUserDefaults standardUserDefaults] setBool:isFFMpeg forKey:ffmpegPath];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL) isFFMpeg {
    return [[NSUserDefaults standardUserDefaults] boolForKey:ffmpegPath];
}

#pragma mark - UDP模式观看视频(默认TCP模式)

+ (void) setUDP:(BOOL)isUDP {
    [[NSUserDefaults standardUserDefaults] setBool:isUDP forKey:udpPath];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL) isUDP {
    return [[NSUserDefaults standardUserDefaults] boolForKey:udpPath];
}

@end
