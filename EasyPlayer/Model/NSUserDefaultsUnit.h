//
//  NSUserDefaultsUnit.h
//  EasyPlayer
//
//  Created by leo on 2017/12/30.
//  Copyright © 2017年 cs. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 设置的管理
 */
@interface NSUserDefaultsUnit : NSObject

#pragma mark - 开启自动播放音频

+ (void) setAutoAudio:(BOOL)isAudio;

+ (BOOL) isAutoAudio;

#pragma mark - 开启视频的同时是否进行录像

+ (void) setAutoRecord:(BOOL)isRecord;

+ (BOOL) isAutoRecord;

#pragma mark - 是否使用FFMpeg进行视频软解码

+ (void) setFFMpeg:(BOOL)isFFMpeg;

+ (BOOL) isFFMpeg;

#pragma mark - key有效期

+ (void) setActiveDay:(int)value;

+ (int) activeDay;

@end
