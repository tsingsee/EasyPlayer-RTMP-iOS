//
//  AppDelegate.m
//  EasyPlayer
//
//  Created by tsinglink on 2017/11/14.
//  Copyright © 2017年 cs. All rights reserved.
//

#import "AppDelegate.h"
#import "RtspDataReader.h"
#import "RootViewController.h"
#import "NSUserDefaultsUnit.h"
#import <Bugly/Bugly.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [Bugly startWithAppId:@"8a4c2e394d"];
    
    if (![NSUserDefaultsUnit urls]) {
        NSMutableArray *a = [[NSMutableArray alloc] init];
        [a addObject:@"rtmp://live.hkstv.hk.lxdns.com/live/hks2"];
        [NSUserDefaultsUnit updateURL:a];
        
        [NSUserDefaultsUnit setFFMpeg:YES];// 默认软解码
    }
    
    [RtspDataReader startUp];
    
    int err = EasyRTMPClient_Activate(
"59615A6742762B32734B7941725370636F3956524576464659584E355547786865575679556C524E55434E58444661672F704C2B4947566863336B3D");
    NSLog(@"---->>>  %d", err);
    
    [[UINavigationBar appearance] setBarTintColor:MAIN_COLOR];
    NSDictionary *dic2 = [NSDictionary dictionaryWithObject:[UIColor whiteColor] forKey:NSForegroundColorAttributeName];
    [[UINavigationBar appearance] setTitleTextAttributes:dic2];
    [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
    
    self.window = [[UIWindow alloc]initWithFrame:[[UIScreen mainScreen]bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[[RootViewController alloc]init]];
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    
//    NSString *pname = [[NSProcessInfo processInfo] processName];
//    NSLog(@"----->>>>  %@", pname);
    
    return YES;
}

@end
