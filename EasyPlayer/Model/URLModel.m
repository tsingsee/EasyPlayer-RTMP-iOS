//
//  URLModel.m
//  EasyPlayerRTMP
//
//  Created by liyy on 2019/4/27.
//  Copyright © 2019年 cs. All rights reserved.
//

#import "URLModel.h"
#import "NSObject+YYModel.h"

@implementation URLModel

- (instancetype) initDefault {
    if (self = [super init]) {
        self.transportMode = EASY_RTP_OVER_TCP;  // 默认tcp
        self.sendOption = 0x01;     // 默认发送心跳
    }
    
    return self;
}

+ (nullable NSDictionary<NSString *, id> *)modelCustomPropertyMapper {
    return @{ @"url" : @"url" };
}

+ (instancetype) convertFromDict:(NSDictionary *)dict {
    URLModel *model = [URLModel modelWithDictionary:dict];
    
    return model;
}

@end
