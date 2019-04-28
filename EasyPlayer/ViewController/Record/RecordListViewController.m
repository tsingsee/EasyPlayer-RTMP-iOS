//
//  RecordListViewController.m
//  EasyPlayer
//
//  Created by liyy on 2017/12/30.
//  Copyright © 2017年 cs. All rights reserved.
//

#import "RecordListViewController.h"
#import "PlayRecordViewController.h"
#import "RecordListCell.h"
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
    RecordListCell *cell = [RecordListCell cellWithTableView:tableView];
    
    NSString *path = [PathUnit snapshotWithURL:_url];
    if([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        cell.infoIV.image = [UIImage imageWithContentsOfFile:path];
    } else {
        cell.infoIV.image = [UIImage imageNamed:@"ImagePlaceholder"];
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 160;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *file = [NSString stringWithFormat:@"%@/%@", [PathUnit baseRecordPathWithURL:_url], _records[indexPath.row]];
    
    PlayRecordViewController *controller = [[PlayRecordViewController alloc] init];
    controller.path = file;
    [self.navigationController pushViewController:controller animated:YES];
}

@end
