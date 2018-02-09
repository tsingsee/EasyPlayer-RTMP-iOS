
#import <UIKit/UIKit.h>
#import "EasyPlayer_Defs.h"

@interface RootViewController : UIViewController

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray *dataArray;

@property (nonatomic, copy) void (^previewMore)(NSString *url);

@end
