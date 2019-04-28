//
//  ScreenShotListViewController.m
//  EasyPlayer
//
//  Created by liyy on 2017/12/30.
//  Copyright © 2017年 cs. All rights reserved.
//

#import "ScreenShotListViewController.h"
#import "ScreenShotListCell.h"
#import "PathUnit.h"

static NSString *collectionCellIdentifier = @"collectionCellIdentifier";

@interface ScreenShotListViewController ()

@property (nonatomic, retain) NSArray *images;

@end

@implementation ScreenShotListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"截图记录";
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    _images = [PathUnit screenShotListWithURL:_url];
}

#pragma mark - UITableViewDatasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _images.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ScreenShotListCell *cell = [ScreenShotListCell cellWithTableView:tableView];
    
    cell.infoIV.backgroundColor = [UIColor blackColor];
    NSString *file = [NSString stringWithFormat:@"%@/%@", [PathUnit baseShotPathWithURL:_url], _images[indexPath.row]];
    cell.infoIV.image = [UIImage imageWithContentsOfFile:file];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 200;
}

@end
