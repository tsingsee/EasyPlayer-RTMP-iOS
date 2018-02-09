//
//  DC_AlertManager.m
//  BTGShop
//
//  Created by Dave on 2017/11/2.
//  Copyright © 2017年 CCDC. All rights reserved.
//

#import "DC_AlertManager.h"
//#import <MBProgressHUD.h>
//#import <SVProgressHUD.h>
#import "UIView+Toast.h"

static DC_AlertManager *_manager = nil;

@implementation DC_AlertManager

+ (instancetype)shareManager{
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        _manager = [[DC_AlertManager alloc] init];
        
    });
   
    return _manager;
    
}

+ (UIAlertController *)getAlertWithTitle:(NSString *)title WithSubTitle:(NSString *)subTitle withSureBtnTitle:(NSString *)str  withStyle:(UIAlertControllerStyle)style Block:(void (^)(NSInteger index))block{
    
    UIAlertController *alertVc = [UIAlertController alertControllerWithTitle:title message:subTitle preferredStyle:style];
    
    UIAlertAction *sure = [UIAlertAction actionWithTitle:str style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
        block(1);
        
    }];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
        block(0);
        
    }];
    
    [alertVc addAction:sure];
    
    [alertVc addAction:cancel];
    
    return alertVc;
    
}

- (void)pickImageWithAlertVc:(UIViewController *)vc withBlock:(void (^)(NSInteger index))block{
    
    UIAlertController *alertVc = [UIAlertController alertControllerWithTitle:@"选择来源" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *takePhoto = [UIAlertAction actionWithTitle:@"相机" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
        block(0);
        
    }];
    
    UIAlertAction *pickImage = [UIAlertAction actionWithTitle:@"相册" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
        block(1);
        
    }];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
        
    }];
    
    [alertVc addAction:takePhoto];
    
    [alertVc addAction:pickImage];
    
    [alertVc addAction:cancel];
    
    [vc presentViewController:alertVc animated:YES completion:nil];
    
    
}


+ (void)alert:(NSString *)message {
    UIAlertView *alertView = [[UIAlertView alloc]
                              initWithTitle:nil
                              message:message
                              delegate:nil
                              cancelButtonTitle:@"确定"
                              otherButtonTitles:nil, nil];
    [alertView show];
    // [alertView release];
}

+ (void)alertWithTitle:(NSString *)title andMessage:(NSString *)message withBtnTitle:(NSString *)btnTitle{
    UIAlertView *alertView = [[UIAlertView alloc]
                              initWithTitle:title
                              message:message
                              delegate:nil
                              cancelButtonTitle:btnTitle
                              otherButtonTitles:nil, nil];
    [alertView show];
    // [alertView release];
}

+ (void)showHudWithMessage:(NSString *)str{
    
    [[UIApplication sharedApplication].keyWindow makeToast:str duration:1 position:CSToastPositionCenter];
    
}

//+ (void)showStatusHudWithMessage:(NSString *)str{
//
//    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeClear];
//
//    [SVProgressHUD setBackgroundColor:[UIColor colorWithWhite:0.5 alpha:0.9]];
//
//    [SVProgressHUD showWithStatus:str];
//
//}
//
//+ (void)showLoadingHudWithMessage:(NSString *)str{
//
//    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeClear];
//
//    [SVProgressHUD setDefaultStyle:SVProgressHUDStyleDark];
//
//    [SVProgressHUD setDefaultAnimationType:SVProgressHUDAnimationTypeNative];
//
//    [SVProgressHUD showWithStatus:str];
//
//}
//
//+ (void)hudDismiss{
//
//    [SVProgressHUD dismiss];
//
//}

@end
