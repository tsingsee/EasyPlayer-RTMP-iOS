//
//  URLModel.h
//  EasyPlayerRTMP
//
//  Created by leo on 2019/4/27.
//  Copyright © 2019年 cs. All rights reserved.
//

#import "BaseModel.h"
#import "EasyTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface URLModel : BaseModel

@property (nonatomic, copy) NSString *url;  // 流地址

// 传输协议：TCP/UDP(EASY_RTP_CONNECT_TYPE：0x01，0x02)
@property (nonatomic, assign) EASY_RTP_CONNECT_TYPE transportMode;

// 发送保活包(心跳：0x00 不发送心跳， 0x01 OPTIONS， 0x02 GET_PARAMETER)
@property (nonatomic, assign) int sendOption;

@property (nonatomic, copy) NSString *audienceNumber;// 当前观看人数

- (instancetype) initDefault;

@end

NS_ASSUME_NONNULL_END
