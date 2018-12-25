
#import "RootViewController.h"
#import "VideoPlayerController.h"
#import "SettingViewController.h"
#import "VideoCell.h"
#import "PathUnit.h"
#import "NSUserDefaultsUnit.h"
#import <CommonCrypto/CommonDigest.h>

@interface RootViewController()<UICollectionViewDelegate, UICollectionViewDataSource>

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

- (void) setting {
    SettingViewController *controller = [[SettingViewController alloc] initWithStoryboard];
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)clickAddBtn {
    [self editAlert:-1];
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
    if([[NSFileManager defaultManager] fileExistsAtPath:path]) {
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
        [self showActionSheet:(int)indexPath.row];
    }
}

#pragma mark - 对话框

- (void)showActionSheet:(int)index {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:cancelAction];
    
    UIAlertAction *OKAction = [UIAlertAction actionWithTitle:@"修改" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self editAlert:index];
    }];
    [alertController addAction:OKAction];
    
    UIAlertAction *moreAction = [UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self delelteAlert:index];
    }];
    [alertController addAction:moreAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)delelteAlert:(int)index {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"确认删除吗？" message:@"" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDefault handler:nil];
    [alertController addAction:cancelAction];
    
    //添加确定到UIAlertController中
    UIAlertAction *OKAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString* url = [self.dataArray objectAtIndex:index];
        [PathUnit deleteBaseRecordPathWithURL:url];
        [PathUnit deleteBaseShotPathWithURL:url];
        
        [self.dataArray removeObjectAtIndex:index];
        [NSUserDefaultsUnit updateURL:self.dataArray];
        [self.collectionView reloadData];
    }];
    [alertController addAction:OKAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)editAlert:(int)index {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"请输入播放地址" message:@"" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDefault handler:nil];
    [alertController addAction:cancelAction];
    
    //添加确定到UIAlertController中
    UIAlertAction *OKAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *tf = alertController.textFields.firstObject;
        NSString* url = [tf.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if(index < 0) {
            [self.dataArray insertObject:url atIndex:0];
        } else {
            [self.dataArray removeObjectAtIndex:index];
            [self.dataArray insertObject:url atIndex:index];
        }
        
        [NSUserDefaultsUnit updateURL:self.dataArray];
        
        [self.collectionView reloadData];
    }];
    [alertController addAction:OKAction];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"rtmp://";
        
        if(index < 0) {
            textField.text = @"rtmp://demo.easydss.com:10085/vlive/IalZ2ZsiR?k=IalZ2ZsiR.75f88a7832a1dd9192";
        } else {
            NSString *url = self.dataArray[index];
            textField.text = url;
        }
    }];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

@end
