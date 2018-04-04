//
//  DC_AlertManager.m
//  BTGShop
//
//  Created by Dave on 2017/11/2.
//  Copyright © 2017年 CCDC. All rights reserved.
//

#import "DC_AlertManager.h"
#import "UIView+Toast.h"

static DC_AlertManager *_manager = nil;

@implementation DC_AlertManager

+ (void)showHudWithMessage:(NSString *)str {
    [[UIApplication sharedApplication].keyWindow makeToast:str duration:1 position:CSToastPositionCenter];
}

@end
