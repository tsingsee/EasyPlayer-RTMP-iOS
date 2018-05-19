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

@end
