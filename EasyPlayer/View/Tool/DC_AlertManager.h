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

+ (instancetype)shareManager;

+ (UIAlertController *)getAlertWithTitle:(NSString *)title WithSubTitle:(NSString *)subTitle withSureBtnTitle:(NSString *)str  withStyle:(UIAlertControllerStyle)style Block:(void (^)(NSInteger index))block;

- (void)pickImageWithAlertVc:(UIViewController *)vc withBlock:(void (^)(NSInteger index))block;

//提示对话框
+ (void)alert:(NSString *)message;
+ (void)alertWithTitle:(NSString *)title andMessage:(NSString *)message withBtnTitle:(NSString *)btnTitle;

/**
 短暂提示
 */
+ (void)showHudWithMessage:(NSString *)str;

/**
 
 加载动画
 
 */
+ (void)showStatusHudWithMessage:(NSString *)str;

/**
 
 加载菊花动画
 */
+ (void)showLoadingHudWithMessage:(NSString *)str;

/**
 
 hud消失
 */
+ (void)hudDismiss;

@end
