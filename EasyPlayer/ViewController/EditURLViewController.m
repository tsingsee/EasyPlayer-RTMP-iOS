//
//  EditURLViewController.m
//  EasyPlayerRTMP
//
//  Created by leo on 2019/4/25.
//  Copyright © 2019年 cs. All rights reserved.
//

#import "EditURLViewController.h"
#import "ScanViewController.h"
#import "URLUnit.h"
#import <WHToast.h>

@interface EditURLViewController ()

@property (weak, nonatomic) IBOutlet UIView *contentView;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UIButton *scanBtn;
@property (weak, nonatomic) IBOutlet UIView *itemView;
@property (weak, nonatomic) IBOutlet UIButton *tcpBtn;
@property (weak, nonatomic) IBOutlet UIButton *updBtn;
@property (weak, nonatomic) IBOutlet UIButton *sendBtn;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *contentViewWidth;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *contentViewHeight;

@property (nonatomic, strong) URLModel *model;

@end

@implementation EditURLViewController

- (instancetype) initWithStoryboard {
    return [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"EditURLViewController"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColorFromRGBA(0x000000, 0.6);
    
    // EasyPlayer RTMP iOS 不需要设置传输协议和保活包
    self.itemView.hidden = YES;
    
    self.contentViewWidth.constant = EasyScreenWidth;
    self.contentViewHeight.constant = EasyScreenHeight;
    
    EasyViewBorderRadius(self.contentView, 4, 0, [UIColor clearColor]);
    
    [self.scanBtn setImage:[UIImage imageNamed:@"scan"] forState:UIControlStateNormal];
    [self.scanBtn setImage:[UIImage imageNamed:@"scan_click"] forState:UIControlStateHighlighted];
    
    [self.tcpBtn setImage:[UIImage imageNamed:@"select"] forState:UIControlStateNormal];
    [self.tcpBtn setImage:[UIImage imageNamed:@"selected"] forState:UIControlStateSelected];
    [self.tcpBtn setTitleColor:UIColorFromRGB(DefaultBtnColor) forState:UIControlStateNormal];
    [self.tcpBtn setTitleColor:UIColorFromRGB(SelectBtnColor) forState:UIControlStateSelected];

    [self.updBtn setImage:[UIImage imageNamed:@"select"] forState:UIControlStateNormal];
    [self.updBtn setImage:[UIImage imageNamed:@"selected"] forState:UIControlStateSelected];
    [self.updBtn setTitleColor:UIColorFromRGB(DefaultBtnColor) forState:UIControlStateNormal];
    [self.updBtn setTitleColor:UIColorFromRGB(SelectBtnColor) forState:UIControlStateSelected];
    
    [self.sendBtn setImage:[UIImage imageNamed:@"select"] forState:UIControlStateNormal];
    [self.sendBtn setImage:[UIImage imageNamed:@"selected"] forState:UIControlStateSelected];
    
    self.model = [[URLModel alloc] initDefault];
    
    if (self.urlModel) {
        self.model.url = self.urlModel.url;
        self.model.transportMode = self.urlModel.transportMode;
        self.model.sendOption = self.urlModel.sendOption;
    }
    
    if (self.model.url) {
        self.textField.text = self.model.url;
    } else {
        self.textField.text = @"rtmp://";
    }
    
    if (self.model.transportMode == EASY_RTP_OVER_TCP) {
        self.tcpBtn.selected = YES;
        self.updBtn.selected = NO;
    } else {
        self.tcpBtn.selected = NO;
        self.updBtn.selected = YES;
    }
    
    if (self.model.sendOption == 0x01) {
        self.sendBtn.selected = YES;
    } else {
        self.sendBtn.selected = NO;
    }
}

#pragma mark - click listener

// tcp
- (IBAction)selectTCP:(id)sender {
    self.tcpBtn.selected = YES;
    self.updBtn.selected = NO;
    
    self.model.transportMode = EASY_RTP_OVER_TCP;
}

// udp
- (IBAction)selectUDP:(id)sender {
    self.tcpBtn.selected = NO;
    self.updBtn.selected = YES;
    
    self.model.transportMode = EASY_RTP_OVER_UDP;
}

// 保活包
- (IBAction)send:(id)sender {
    self.sendBtn.selected = !self.sendBtn.selected;
    
    if (self.sendBtn.selected) {
        self.model.sendOption = 0x01;
    } else {
        self.model.sendOption = 0x00;
    }
}

// 去扫描二维码
- (IBAction)scan:(id)sender {
    ScanViewController *vc = [[ScanViewController alloc] initWithStoryboard];
    [vc.subject subscribeNext:^(NSString *url) {
        self.textField.text = url;
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

// 取消
- (IBAction)cancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// 确定
- (IBAction)submit:(id)sender {
    NSString *text = self.textField.text;
    
    if (text.length == 0) {
        [WHToast showMessage:@"请输入流地址" duration:2 finishHandler:nil];
        return;
    }
    
    if (![text hasPrefix:@"rtmp://"]) {
        [WHToast showMessage:@"请输入正确的流地址" duration:2 finishHandler:nil];
        return;
    }
    
    self.model.url = text;
    
    if (self.urlModel) {
        [URLUnit updateURLModel:self.model oldModel:self.urlModel];
    } else {
        [URLUnit addURLModel:self.model];
    }
    
    [self.subject sendNext:nil];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (RACSubject *) subject {
    if (!_subject) {
        _subject = [RACSubject subject];
    }
    
    return _subject;
}

@end
