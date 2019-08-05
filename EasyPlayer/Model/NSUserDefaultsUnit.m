//
//  NSUserDefaultsUnit.m
//  EasyPlayer
//
//  Created by leo on 2017/12/30.
//  Copyright © 2017年 cs. All rights reserved.
//

#import "NSUserDefaultsUnit.h"

static NSString *audioPath = @"audioPath";
static NSString *recordPath = @"recordPath";
static NSString *ffmpegPath = @"ffmpegPath";
static NSString *udpPath = @"udpPath";
static NSString *activeDay = @"activeDay";

@implementation NSUserDefaultsUnit

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

#pragma mark - key有效期

+ (void) setActiveDay:(int)value {
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:activeDay];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (int) activeDay {
    return (int)[[NSUserDefaults standardUserDefaults] integerForKey:activeDay];
}

@end
