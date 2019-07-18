//
//  AppDelegate.m
//  EasyPlayer
//
//  Created by tsinglink on 2017/11/14.
//  Copyright © 2017年 cs. All rights reserved.
//

#import "AppDelegate.h"
#import "PlayerDataReader.h"
#import "RootViewController.h"
#import "NSUserDefaultsUnit.h"
#import "URLUnit.h"

#import <RTRootNavigationController/RTRootNavigationController.h>
#import <IQKeyboardManager/IQKeyboardManager.h>
#import <Bugly/Bugly.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    if (![URLUnit urlModels]) {
        URLModel *model = [[URLModel alloc] initDefault];
        model.url = @"rtmp://live.hkstv.hk.lxdns.com/live/hks2";
        [URLUnit addURLModel:model];
        
        [NSUserDefaultsUnit setFFMpeg:YES];     // 默认软解码
        [NSUserDefaultsUnit setAutoAudio:YES];  // 默认自动播放音频
    }
    
    [PlayerDataReader startUp];
    
    int days = EasyRTMPClient_Activate(
                                       "59615A6742762B32734B7941725370636F3956524576464659584E355547786865575679556C524E55434E58444661672F704C2B4947566863336B3D");
    NSLog(@"key有效期：%d", days);
    [NSUserDefaultsUnit setActiveDay:days];
    
    // Bugly
    [Bugly startWithAppId:@"8a4c2e394d"];
    
    // IQKeyboardManager
    IQKeyboardManager *keyboardManager = [IQKeyboardManager sharedManager]; // 获取类库的单例变量
    keyboardManager.enable = YES; // 控制整个功能是否启用
    keyboardManager.shouldResignOnTouchOutside = YES; // 控制点击背景是否收起键盘
    keyboardManager.shouldToolbarUsesTextFieldTintColor = YES; // 控制键盘上的工具条文字颜色是否用户自定义
    keyboardManager.toolbarManageBehaviour = IQAutoToolbarBySubviews; // 有多个输入框时，可以通过点击Toolbar 上的“前一个”“后一个”按钮来实现移动到不同的输入框
    keyboardManager.enableAutoToolbar = YES; // 控制是否显示键盘上的工具条
    keyboardManager.toolbarDoneBarButtonItemText = @"完成";
    keyboardManager.shouldShowToolbarPlaceholder = YES; // 是否显示占位文字
    keyboardManager.placeholderFont = [UIFont boldSystemFontOfSize:17]; // 设置占位文字的字体
    keyboardManager.keyboardDistanceFromTextField = 10.0f; // 输入框距离键盘的距离
    
    // UI逻辑
    CGRect frame = CGRectMake(0, 0, EasyScreenWidth, EasyScreenHeight);
    self.window = [[UIWindow alloc] initWithFrame:frame];
    self.window.backgroundColor = UIColorFromRGB(0xf5f5f5);
    [self.window makeKeyAndVisible];
    
    // 设置UI
    RootViewController *vc = [[RootViewController alloc] initWithStoryboard];
    RTRootNavigationController *rootVC = [[RTRootNavigationController alloc] init];
    [rootVC setViewControllers:@[ vc ]];
    
    self.window.rootViewController = rootVC;
    
    NSString *pname = [[NSProcessInfo processInfo] processName];
    NSLog(@"进程名：%@", pname);
    
    return YES;
}

@end
