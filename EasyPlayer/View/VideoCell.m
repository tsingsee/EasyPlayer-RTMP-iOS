
#import "VideoCell.h"

// ----------------  设置颜色 ----------------
#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

#define UIColorFromRGBA(rgbValue,trans) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:trans]

@implementation VideoCell

- (id)initWithFrame:(CGRect)frame {
    if(self = [super initWithFrame:frame]) {
        self.layer.masksToBounds = NO;
        self.layer.contentsScale = [UIScreen mainScreen].scale;
        self.layer.borderColor = [[UIColor grayColor] CGColor];
        self.layer.borderWidth = 0.5;
        self.layer.shadowOpacity = 0.5;
        self.layer.shadowColor = [[UIColor grayColor] CGColor];
        self.layer.shadowRadius = 5;
        self.layer.shadowOffset  = CGSizeZero;
        self.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.bounds].CGPath;
        
        CGRect imgRect = { CGPointZero, {self.contentView.frame.size.width, self.contentView.frame.size.height - VIDEO_TITLE_HEIGHT}};
        self.imageView = [[UIImageView alloc]initWithFrame:imgRect];
        self.imageView.image = [UIImage imageNamed:@"ImagePlaceholder"];
        self.imageView.backgroundColor = UIColorFromRGBA(0xffffff, 0.3);
        [self.contentView addSubview: self.imageView];
        
        self.titleLabel = [[UILabel alloc]initWithFrame:CGRectMake(0,self.contentView.frame.size.height-VIDEO_TITLE_HEIGHT, self.contentView.frame.size.width, VIDEO_TITLE_HEIGHT)];
        self.titleLabel.font = [UIFont systemFontOfSize:14];
        self.titleLabel.textColor = UIColorFromRGB(0x333333);
        self.titleLabel.backgroundColor = UIColorFromRGBA(0x000000, 0.3);
        [self bringSubviewToFront:self.titleLabel];
        [self.contentView addSubview:self.titleLabel];
    }
    
    return self;
}

@end
