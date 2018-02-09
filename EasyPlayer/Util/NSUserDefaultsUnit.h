//
//  NSUserDefaultsUnit.h
//  EasyPlayer
//
//  Created by liyy on 2017/12/30.
//  Copyright © 2017年 cs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSUserDefaultsUnit : NSObject

#pragma mark - 播放url的存储

// 获取所有url
+ (NSMutableArray *) urls;

// 添加/删除url
+ (void) updateURL:(NSMutableArray *)urls;

#pragma mark - 开启自动播放音频

+ (void) setAutoAudio:(BOOL)isAudio;

+ (BOOL) isAutoAudio;

#pragma mark - 开启视频的同时是否进行录像

+ (void) setAutoRecord:(BOOL)isRecord;

+ (BOOL) isAutoRecord;

#pragma mark - 是否使用FFMpeg进行视频软解码

+ (void) setFFMpeg:(BOOL)isFFMpeg;

+ (BOOL) isFFMpeg;

#pragma mark - UDP模式观看视频(默认TCP模式)

+ (void) setUDP:(BOOL)isUDP;

+ (BOOL) isUDP;

@end
