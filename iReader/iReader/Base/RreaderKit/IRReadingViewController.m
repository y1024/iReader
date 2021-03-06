//
//  IRReadingViewController.m
//  iReader
//
//  Created by zzyong on 2018/8/17.
//  Copyright © 2018年 zouzhiyong. All rights reserved.
//

#import "IRReadingViewController.h"
#import "DTAttributedLabel.h"
#import "IRPageModel.h"
#import <Masonry.h>

@interface IRReadingViewController ()

@property (nonatomic, strong) DTAttributedLabel *pageLabel;
@property (nonatomic, strong) UIImageView *backgroundImgView;
@property (nonatomic, strong) UIActivityIndicatorView *chapterLoadingHUD;

@end

@implementation IRReadingViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupSubviews];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    _pageLabel.frame = self.view.bounds;
    _backgroundImgView.frame = self.view.bounds;
}

#pragma mark - Loading HUD

- (NSUInteger)activityIndicatorViewTag
{
    return 999;
}

- (void)showChapterLoadingHUD
{
    if (!self.chapterLoadingHUD) {
        self.chapterLoadingHUD = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        self.chapterLoadingHUD.backgroundColor = [UIColor clearColor];
        self.chapterLoadingHUD.hidesWhenStopped = YES;
        self.chapterLoadingHUD.color = [UIColor lightGrayColor];
        self.chapterLoadingHUD.tag = [self activityIndicatorViewTag];
        [self.view addSubview:self.chapterLoadingHUD];
    }
    
    [self.view addSubview:self.chapterLoadingHUD];
    [self.view bringSubviewToFront:self.chapterLoadingHUD];
    [self.chapterLoadingHUD mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    [self.chapterLoadingHUD startAnimating];
    
    self.chapterLoadingHUD.alpha = 0;
    [UIView animateWithDuration:0.25 animations:^{
        self.chapterLoadingHUD.alpha = 1;
    }];
}

- (void)dismissChapterLoadingHUD
{
    UIActivityIndicatorView *loadingView = [self.chapterLoadingHUD viewWithTag:[self activityIndicatorViewTag]];
    [loadingView stopAnimating];
    [UIView animateWithDuration:0.25 animations:^{
        self.chapterLoadingHUD.alpha = 0;
    } completion:^(BOOL finished) {
        [self.chapterLoadingHUD removeFromSuperview];
        self.chapterLoadingHUD.alpha = 1;
    }];
}

#pragma mark - Private

- (void)setupSubviews
{
    self.pageLabel = [[DTAttributedLabel alloc] init];
    self.pageLabel.backgroundColor = [UIColor clearColor];
    self.pageLabel.edgeInsets = IR_READER_CONFIG.pageInsets;
    self.pageLabel.numberOfLines = 0;
    [self.view addSubview:self.pageLabel];
}

- (UIImageView *)backgroundImgView
{
    if (_backgroundImgView) {
        _backgroundImgView = [[UIImageView alloc] init];
        [self.view addSubview:_backgroundImgView];
        [self.view sendSubviewToBack:_backgroundImgView];
    }
    return _backgroundImgView;
}

- (void)setPageModel:(IRPageModel *)pageModel
{
    _pageModel = pageModel;
    
    if (IR_READER_CONFIG.readerBgImg && !IR_READER_CONFIG.isNightMode) {
        self.backgroundImgView.image = IR_READER_CONFIG.readerBgImg;
    } else {
        self.view.backgroundColor = IR_READER_CONFIG.readerBgColor;
    }
    
    self.pageLabel.attributedString = pageModel.content;
    
    if (pageModel) {
        [self dismissChapterLoadingHUD];
    } else {
        [self showChapterLoadingHUD];
    }
}

@end
