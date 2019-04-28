//
//  SettingViewController.m
//  EasyPlayer
//
//  Created by liyy on 2017/12/30.
//  Copyright © 2017年 cs. All rights reserved.
//

#import "SettingViewController.h"
#import "NSUserDefaultsUnit.h"

@interface SettingViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *isAudioSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *isRecordSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *isFFMpegSwitch;

@end

@implementation SettingViewController

- (instancetype) initWithStoryboard {
    return [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"SettingViewController"];
}

#pragma mark - init

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"设置";
    
    [_isAudioSwitch setOnTintColor:UIColorFromRGB(SelectBtnColor)];
    [_isRecordSwitch setOnTintColor:UIColorFromRGB(SelectBtnColor)];
    [_isFFMpegSwitch setOnTintColor:UIColorFromRGB(SelectBtnColor)];
    
    _isAudioSwitch.on = [NSUserDefaultsUnit isAutoAudio];
    _isRecordSwitch.on = [NSUserDefaultsUnit isAutoRecord];
    _isFFMpegSwitch.on = [NSUserDefaultsUnit isFFMpeg];
    
    self.tableView.backgroundColor = UIColorFromRGB(0xFFFFFF);
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

#pragma mark - UITableViewDelegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
