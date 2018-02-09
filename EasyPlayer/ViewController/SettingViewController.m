//
//  SettingViewController.m
//  EasyPlayer
//
//  Created by liyy on 2017/12/30.
//  Copyright © 2017年 cs. All rights reserved.
//

#import "SettingViewController.h"
#import "FileListViewController.h"
#import "AboutViewController.h"
#import "NSUserDefaultsUnit.h"

@interface SettingViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *isAudioSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *isRecordSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *isFFMpegSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *isUDPSwitch;

@end

@implementation SettingViewController

- (instancetype) initWithStoryboard {
    return [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"SettingViewController"];
}

#pragma mark - init

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"设置";
    
    _isAudioSwitch.on = [NSUserDefaultsUnit isAutoAudio];
    _isRecordSwitch.on = [NSUserDefaultsUnit isAutoRecord];
    _isFFMpegSwitch.on = [NSUserDefaultsUnit isFFMpeg];
    _isUDPSwitch.on = [NSUserDefaultsUnit isUDP];
}

#pragma mark - click event

- (IBAction)isAudio:(id)sender {
    [NSUserDefaultsUnit setAutoAudio:_isAudioSwitch.on];
}

// 开启视频的同时进行录像
- (IBAction)isRecord:(id)sender {
    [NSUserDefaultsUnit setAutoRecord:_isRecordSwitch.on];
}

// 使用FFMpeg进行视频软解码
- (IBAction)isFFMpeg:(id)sender {
    [NSUserDefaultsUnit setFFMpeg:_isFFMpegSwitch.on];
}

// UDP模式观看视频(默认TCP模式)
- (IBAction)isUDP:(id)sender {
    [NSUserDefaultsUnit setUDP:_isUDPSwitch.on];
}

#pragma mark - UITableViewDelegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    switch (indexPath.row) {
        case 3:{ // 关于我们
            AboutViewController *controller = [[AboutViewController alloc] initWithStoryboard];
            [self.navigationController pushViewController:controller animated:YES];
        }
            break;
        case 4:{ // 截图记录
            FileListViewController *controller = [[FileListViewController alloc] init];
            controller.isScreenShopList = YES;
            [self.navigationController pushViewController:controller animated:YES];
        }
            break;
        case 5:{ // 录像记录
            FileListViewController *controller = [[FileListViewController alloc] init];
            controller.isScreenShopList = NO;
            [self.navigationController pushViewController:controller animated:YES];
        }
            break;
        default:
            break;
    }
}

@end
