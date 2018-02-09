//
//  RecordListViewController.m
//  EasyPlayer
//
//  Created by liyy on 2017/12/30.
//  Copyright © 2017年 cs. All rights reserved.
//

#import "RecordListViewController.h"
#import "ScreenShotListCell.h"
#import "PathUnit.h"

@interface RecordListViewController ()

@property (nonatomic, retain) NSArray *records;

@end

@implementation RecordListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"录像记录";
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    _records = [PathUnit recordListWithURL:_url];
}

#pragma mark - UITableViewDatasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _records.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ScreenShotListCell *cell = [ScreenShotListCell cellWithTableView:tableView];
    
    
    // TODO
    cell.infoIV.backgroundColor = [UIColor blackColor];
    NSString *file = [NSString stringWithFormat:@"%@/%@", [PathUnit baseRecordPathWithURL:_url], _records[indexPath.row]];
    cell.infoIV.image = [UIImage imageWithContentsOfFile:file];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 180;
}

@end
