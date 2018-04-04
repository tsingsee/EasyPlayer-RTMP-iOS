//
//  DC_AlertManager.h
//  BTGShop
//
//  Created by Dave on 2017/11/2.
//  Copyright © 2017年 CCDC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface DC_AlertManager : NSObject

/**
 短暂提示
 */
+ (void)showHudWithMessage:(NSString *)str;

@end
