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

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    if (![NSUserDefaultsUnit urls]) {
        NSMutableArray *a = [[NSMutableArray alloc] init];
        [a addObject:@"rtmp://live.hkstv.hk.lxdns.com/live/hks"];
        [NSUserDefaultsUnit updateURL:a];
        
        [NSUserDefaultsUnit setFFMpeg:YES];// 默认软解码
    }
    
    [RtspDataReader startUp];
    
    int err = EasyRTMPClient_Activate(
"59617A414C662B32734B79415170646170576938792F464659584E355547786865575679556C524E55477858444661672F307667523246326157346D516D466962334E68514449774D545A4659584E355247467964326C75564756686257566863336B3D");
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
