//
//  FileListViewController.m
//  EasyPlayer
//
//  Created by liyy on 2017/12/30.
//  Copyright © 2017年 cs. All rights reserved.
//

#import "FileListViewController.h"
#import "ScreenShotListViewController.h"
#import "RecordListViewController.h"
#import "NSUserDefaultsUnit.h"

@interface FileListViewController ()

@property (nonatomic, retain) NSArray *urls;

@end

@implementation FileListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"选择摄像头";
    
    // 把多余的分割线去掉
    UIView * footerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.tableFooterView = footerView;
    
    _urls = [NSUserDefaultsUnit urls];
}

#pragma mark - UITableViewDatasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _urls.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    // 2.创建
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.text = _urls[indexPath.row];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 80;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (_isScreenShopList) {
        ScreenShotListViewController *controller = [[ScreenShotListViewController alloc] init];
        controller.url = _urls[indexPath.row];
        [self.navigationController pushViewController:controller animated:YES];
    } else {
        RecordListViewController *controller = [[RecordListViewController alloc] init];
        controller.url = _urls[indexPath.row];
        [self.navigationController pushViewController:controller animated:YES];
    }
}

@end
