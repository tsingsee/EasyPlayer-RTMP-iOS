//
//  URLUnit.h
//  EasyPlayerRTMP
//
//  Created by leo on 2019/4/27.
//  Copyright © 2019年 cs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MyURLModel.h"

NS_ASSUME_NONNULL_BEGIN

/**
 流地址的管理
 */
@interface URLUnit : NSObject

#pragma mark - 播放url的存储

// 获取所有url
+ (NSMutableArray *) urlModels;

// 添加rl
+ (void) addURLModel:(MyURLModel *)model;
+ (void) updateURLModel:(MyURLModel *)model oldModel:(MyURLModel *)m;

// 删除url
+ (void) removeURLModel:(MyURLModel *)model;

@end

NS_ASSUME_NONNULL_END
