//
//  BookChapterListController.h
//  iReader
//
//  Created by zzyong on 2018/7/13.
//  Copyright © 2018年 zouzhiyong. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol BookChapterListControllerDelegate <NSObject>

- (void)bookChapterListControllerDidSelectChapterAtIndex:(NSUInteger)index;

@end

@class IRTocRefrence;

@interface BookChapterListController : UIViewController

@property (nonatomic, strong) NSArray<IRTocRefrence *> *chapterList;
@property (nonatomic, assign) NSUInteger selectChapterIndex;
@property (nonatomic, weak) id<BookChapterListControllerDelegate> delegate;

@end
