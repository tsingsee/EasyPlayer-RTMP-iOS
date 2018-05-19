//
//  UIColor+HexColor.m
//  Text2Group
//
//  Created by chenshun on 13-4-13.
//  Copyright (c) 2013年 ChenShun. All rights reserved.
//

#import "UIColor+HexColor.h"

#define HEXCOLOR(rgbValue, alpa) \
[UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
green:((float)((rgbValue & 0xFF00) >> 8))/255.0 \
blue:((float)(rgbValue & 0xFF))/255.0 alpha:alpa]

@implementation UIColor (HexColor)

+ (UIColor *)colorFromHex:(NSInteger)value {
    return HEXCOLOR(value, 1);
}

+ (UIColor *)colorWithHex:(NSInteger)value alpa:(float)alpa {
    return HEXCOLOR(value, alpa);
}

@end
