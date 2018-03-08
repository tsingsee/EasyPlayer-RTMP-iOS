
#import "RootViewController.h"
#import "VideoPlayerController.h"
#import "SettingViewController.h"
#import "VideoCell.h"
#import "PathUnit.h"
#import "NSUserDefaultsUnit.h"
#import <CommonCrypto/CommonDigest.h>

@interface RootViewController()<UICollectionViewDelegate,UICollectionViewDataSource,UIActionSheetDelegate> {
    UIAlertView* _alertView;
    UIAlertView* _deleteAlertView;
    UIActionSheet* _actionSheet;
}

@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self navigationSetting];
    self.navigationItem.title = @"EasyPlayer";
    self.view.backgroundColor = [UIColor whiteColor];
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc]init];
    //定义每个UICollectionView 横向的间距
    layout.minimumLineSpacing = 10;
    //定义每个UICollectionView 纵向的间距
    layout.minimumInteritemSpacing = 10;
    //定义每个UICollectionView 的边距距
    layout.sectionInset = UIEdgeInsetsMake(10, 10, 10, 10);//上左下右
    self.collectionView = [[UICollectionView alloc]initWithFrame:CGRectMake(0, 0, ScreenWidth, ScreenHeight) collectionViewLayout:layout];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.backgroundColor = [UIColor whiteColor];
    [self.collectionView registerClass:[VideoCell class] forCellWithReuseIdentifier:@"VideoCell"];
    [self.view addSubview:self.collectionView];
    
    _alertView = [[UIAlertView alloc] initWithTitle:@"请输入播放地址" message: nil delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
    [_alertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
    [_alertView textFieldAtIndex:0].keyboardType = UIKeyboardTypeURL;
    
    _deleteAlertView = [[UIAlertView alloc] initWithTitle:@"确定删除?" message:nil delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
    _actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:@"删除" otherButtonTitles:@"修改", nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    NSMutableArray *urls = [NSUserDefaultsUnit urls];
    if(urls) {
        _dataArray = [urls mutableCopy];
    } else {
        _dataArray = [NSMutableArray array];
    }
    
    [self.collectionView reloadData];
}

- (void)doReload {
    [self.collectionView reloadData];
}

// 导航栏设置
- (void)navigationSetting {
    [self.navigationController.navigationBar setTitleTextAttributes:@{ NSFontAttributeName:[UIFont systemFontOfSize:17], NSForegroundColorAttributeName:[UIColor whiteColor] }];
    
    if (self.previewMore != nil) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelVc)];
    } else {
        UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"EasyPlayer_60"]];
        iv.frame = CGRectMake(0, 0, 36, 36);
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:iv];
        self.navigationItem.leftBarButtonItem = item;
    }
    
    UIBarButtonItem *setBtn = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"set"] style:UIBarButtonItemStyleDone target:self action:@selector(setting)];
    UIBarButtonItem *addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(clickAddBtn)];
    self.navigationItem.rightBarButtonItems = @[setBtn, addBtn];
}

#pragma mark - click event

- (void)cancelVc {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)clickAddBtn {
    // rtmp://live.hkstv.hk.lxdns.com/live/hks
    // rtmp://live.finding.com/live/C09?auth_key=1517917594-0-0-a0b1215b36b9f5958783f9fdce1838de
    // rtmp://www.easydss.com:10085/live/stream_270878
    // rtmp://www.easydss.com:10085/live/testid
    // rtmp://live.finding.com/live/C04?auth_key=1519629069-0-0-a37a75e09891fbe6d54c11dd4caf0cee
    
    [_alertView textFieldAtIndex:0].text = @"rtmp://";
    _alertView.tag = -1;
    [_alertView show];
}

- (void) setting {
    SettingViewController *controller = [[SettingViewController alloc] initWithStoryboard];
    [self.navigationController pushViewController:controller animated:YES];
}

#pragma mark - UIActionSheetDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if(alertView == _alertView && buttonIndex == 1) {
        UITextField *tf = [_alertView textFieldAtIndex:0];
        NSString* url = [tf.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if(_alertView.tag < 0) {
            [_dataArray insertObject:url atIndex:0];
        } else {
            [_dataArray removeObjectAtIndex:_alertView.tag];
            [_dataArray insertObject:url atIndex:_alertView.tag];
        }
        
        [NSUserDefaultsUnit updateURL:_dataArray];
        
        [self.collectionView reloadData];
    }
    
    if(alertView == _deleteAlertView && buttonIndex == 1) {
        NSString* url = [_dataArray objectAtIndex:_deleteAlertView.tag];
        [PathUnit deleteBaseRecordPathWithURL:url];
        [PathUnit deleteBaseShotPathWithURL:url];
        
        [_dataArray removeObjectAtIndex:_deleteAlertView.tag];
        [NSUserDefaultsUnit updateURL:_dataArray];
        [self.collectionView reloadData];
    }
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if(actionSheet == _actionSheet) {
        switch (buttonIndex) {
            case 0: { // delete
                _deleteAlertView.tag = _actionSheet.tag;
                [_deleteAlertView show];
                break;
            }
            case 1: { // edit
                _alertView.tag = _actionSheet.tag;
                UITextField *tf = [_alertView textFieldAtIndex:0];
                tf.text = [_dataArray objectAtIndex:_alertView.tag];
                [_alertView show];
                break;
            }
            default:
                break;
        }
    }
}

#pragma mark - UICollectionViewDataSource

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _dataArray.count;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    int w = ScreenWidth - 20;
    int h = w * 9 / 16;
    return CGSizeMake(w, h + VIDEO_TITLE_HEIGHT);// 30 is the bottom title height
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    VideoCell * cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"VideoCell" forIndexPath:indexPath];
    NSString *url = _dataArray[indexPath.row];
    
    NSString *path = [PathUnit snapshotWithURL:url];
    if([[NSFileManager defaultManager] fileExistsAtPath:path]){
        cell.imageView.image = [UIImage imageWithContentsOfFile:path];
    } else {
        cell.imageView.image = [UIImage imageNamed:@"ImagePlaceholder"];
    }
    
    [cell.titleLabel setText:[NSString stringWithFormat:@"%@",url]];
    
    UILongPressGestureRecognizer* longgs=[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(longpress:)];
    [cell addGestureRecognizer:longgs];
    longgs.minimumPressDuration=0.3;
    longgs.view.tag=indexPath.row;
    
    return cell;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.previewMore != nil) {
        [self cancelVc];
        self.previewMore(_dataArray[indexPath.row]);
    } else {
        VideoPlayerController* pvc = [[VideoPlayerController alloc] init];
        pvc.url = _dataArray[indexPath.row];
        [self.navigationController pushViewController:pvc animated:YES];
    }
}

#pragma mark - GestureRecognizer

-(void)longpress:(UILongPressGestureRecognizer *)ges {
    CGPoint pointTouch = [ges locationInView:self.collectionView];
    if(ges.state == UIGestureRecognizerStateBegan) {
        NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:pointTouch];
        _actionSheet.tag = indexPath.row;
        [_actionSheet showInView:self.view];
    }
}

@end
