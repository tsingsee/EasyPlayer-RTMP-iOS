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

@end

@implementation SettingViewController

- (instancetype) initWithStoryboard {
    return [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"SettingViewController"];
}

#pragma mark - init

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"设置";
}

#pragma mark - UITableViewDelegate

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    switch (indexPath.row) {
        case 0:{ // 截图记录
            FileListViewController *controller = [[FileListViewController alloc] init];
            controller.isScreenShopList = YES;
            [self.navigationController pushViewController:controller animated:YES];
        }
            break;
        case 1:{ // 录像记录
            FileListViewController *controller = [[FileListViewController alloc] init];
            controller.isScreenShopList = NO;
            [self.navigationController pushViewController:controller animated:YES];
        }
            break;
        case 2:{ // 关于我们
            AboutViewController *controller = [[AboutViewController alloc] initWithStoryboard];
            [self.navigationController pushViewController:controller animated:YES];
        }
            break;
        default:
            break;
    }
}

@end
