//
//  IRPageModel.m
//  iReader
//
//  Created by zzyong on 2018/7/27.
//  Copyright © 2018年 zouzhiyong. All rights reserved.
//

#import "IRPageModel.h"

@implementation IRPageModel

+ (instancetype)modelWithContent:(NSAttributedString *)content
{
    IRPageModel *model = [[self alloc] init];
    model.content = content;
    
    return model;
}

@end
