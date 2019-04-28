//
//  RecordListCell.h
//  BTG
//
//  Created by liyy on 2017/11/6.
//  Copyright © 2017年 CCDC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RecordListCell : UITableViewCell

@property (nonatomic, retain) UIImageView *infoIV;

+ (instancetype)cellWithTableView:(UITableView *)tableView;

@end
