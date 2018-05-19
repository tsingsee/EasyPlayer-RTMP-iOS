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

@end
