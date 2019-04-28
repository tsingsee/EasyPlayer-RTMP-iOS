//
//  HRGBaseModel.h
//  SHAREMEDICINE_SHOP_iOS
//
//  Created by lyy on 2018/11/19.
//  Copyright © 2018 HRG. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<YYModel/YYModel.h>)
    FOUNDATION_EXPORT double YYModelVersionNumber;
    FOUNDATION_EXPORT const unsigned char YYModelVersionString[];
    #import <YYModel/NSObject+YYModel.h>
    #import <YYModel/YYClassInfo.h>
#else
    #import "NSObject+YYModel.h"
    #import "YYClassInfo.h"
#endif

/**
 model的基类
 */
@interface HRGBaseModel : NSObject<NSCoding, NSCopying>

+ (instancetype) convertFromDict:(NSDictionary *)dict;
+ (NSMutableArray *) convertFromArray:(NSArray *)array;

@end
