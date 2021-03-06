//
//  IRReaderCenterController.m
//  iReader
//
//  Created by zzyong on 2018/8/6.
//  Copyright © 2018年 zouzhiyong. All rights reserved.
//

#import "IRReaderCenterController.h"
#import "BookChapterListController.h"
#import "IRPageViewController.h"
#import "IRReadingViewController.h"
#import "IRReadingBackViewController.h"

// view
#import "IRReaderNavigationView.h"
#import "IRReaderSettingView.h"

// model
#import "IRTocRefrence.h"
#import "IREpubBook.h"
#import "IRChapterModel.h"
#import "IRResource.h"
#import "IRPageModel.h"

// other
#import "AppDelegate.h"

@interface IRReaderCenterController ()
<
UIPageViewControllerDataSource,
UIPageViewControllerDelegate,
IRReaderNavigationViewDelegate,
UIScrollViewDelegate,
BookChapterListControllerDelegate,
ReaderSettingViewDeletage,
UIGestureRecognizerDelegate
>

@property (nonatomic, strong) dispatch_queue_t chapter_parse_serial_queue;
@property (nonatomic, strong) IREpubBook *book;
@property (nonatomic, strong) IRPageViewController *pageViewController;
@property (nonatomic, strong) IRReadingViewController *currentReadingViewController;
@property (nonatomic, assign) NSUInteger chapterCount;
@property (nonatomic, strong) NSMutableArray *chapters;
@property (nonatomic, assign) BOOL shouldHideStatusBar;
@property (nonatomic, strong) IRReaderNavigationView *readerNavigationView;
@property (nonatomic, strong) UINavigationBar *orilNavigationBar;
@property (nonatomic, assign) BOOL shouldUpdateSettingViewState;
@property (nonatomic, assign) BOOL fromChapterListView;
@property (nonatomic, strong) NSMutableArray<IRReadingViewController *> *childViewControllersCache;
@property (nonatomic, assign) BOOL reloadDataIfNeeded;
@property (nonatomic, assign) CGPoint scrollBeginOffset;
@property (nonatomic, assign) BOOL isScrollToNext;
@property (nonatomic, strong) IRPageModel *currentPage;
@property (nonatomic, strong) IRPageModel *nextPage;
@property (nonatomic, assign) NSUInteger chapterSelectIndex;
@property (nonatomic, assign) NSUInteger pageSelectIndex;
@property (nonatomic, weak) IRReaderSettingView *readerSettingView;
@property (nonatomic, assign) BOOL changeNavigationOrientationByUser;

@end

@implementation IRReaderCenterController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self commonInit];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.readerNavigationView shouldHideAllCustomViews:NO];
    
    if (self.fromChapterListView) {
        self.fromChapterListView = NO;
        [self updateReaderSettingViewStateWithAnimated:NO completion:nil];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (self.shouldUpdateSettingViewState) {
        [self updateReaderSettingViewStateWithAnimated:YES completion:^{
            self.shouldUpdateSettingViewState = NO;
        }];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self.readerNavigationView shouldHideAllCustomViews:YES];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    self.pageViewController.view.frame = self.view.bounds;
}

#pragma mark - Setter/Getter

- (IRReaderNavigationView *)readerNavigationView
{
    if (!_readerNavigationView) {
        _readerNavigationView = [[IRReaderNavigationView alloc] init];
        _readerNavigationView.actionDelegate = self;
    }
    
    return _readerNavigationView;
}

- (NSMutableArray<IRChapterModel *> *)chapters
{
    if (!_chapters) {
        _chapters = [[NSMutableArray alloc] initWithCapacity:self.chapterCount];
        for (int index = 0; index < self.chapterCount; index++) {
            [_chapters addObject:[NSNull null]];
        }
    }
    
    return _chapters;
}

- (NSMutableArray<IRReadingViewController *> *)childViewControllersCache
{
    if (!_childViewControllersCache) {
        _childViewControllersCache = [[NSMutableArray alloc] init];
    }
    
    return _childViewControllersCache;
}

#pragma mark - StatusBarHidden

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
}

- (BOOL)prefersStatusBarHidden
{
    return self.shouldHideStatusBar;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return UIStatusBarAnimationSlide;
}

#pragma mark - Gesture

- (void)setupGestures
{
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onSingleTap:)];
    singleTap.numberOfTapsRequired = 1;
    singleTap.delegate = self;
    [self.view addGestureRecognizer:singleTap];
}

- (void)onSingleTap:(UIGestureRecognizer *)recognizer
{
    if (self.shouldUpdateSettingViewState) {
        return;
    }
    
    [self updateReaderSettingViewStateWithAnimated:YES completion:nil];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (self.readerSettingView && CGRectContainsPoint(self.readerSettingView.frame, [gestureRecognizer locationInView:self.view])) {
        return NO;
    }
    
    if (CGRectContainsPoint(CGRectMake(CGRectGetMidX(self.view.frame) - 50, CGRectGetMidY(self.view.frame) - 100, 100, 200), [gestureRecognizer locationInView:self.view])) {
        return YES;
    }
    
    return NO;
}

#pragma mark - Private

- (void)commonInit
{
    self.view.backgroundColor = [UIColor whiteColor];
    self.shouldHideStatusBar = NO;
    self.shouldUpdateSettingViewState = YES;
    [self setupPageViewController];
    [self setupNavigationbar];
    [self setupGestures];
}

- (void)setupNavigationbar
{
    if ([self.navigationController respondsToSelector:@selector(navigationBar)]) {
        [self.navigationController setValue:self.readerNavigationView forKeyPath:@"navigationBar"];
    } else {
        NSAssert(NO, @"UINavigationController does not recognize selector : navigationBar");
    }
}

- (void)setupPageViewController
{
    UIPageViewControllerNavigationOrientation orientation = UIPageViewControllerNavigationOrientationHorizontal;
    if (ReaderPageNavigationOrientationVertical == IR_READER_CONFIG.readerPageNavigationOrientation) {
        orientation = UIPageViewControllerNavigationOrientationVertical;
    }
    [self updatePageViewControllerWithNavigationOrientation:orientation
                                            transitionStyle:UIPageViewControllerTransitionStylePageCurl];
}

- (void)updatePageViewControllerWithNavigationOrientation:(UIPageViewControllerNavigationOrientation)orientation
                                          transitionStyle:(UIPageViewControllerTransitionStyle)transitionStyle
{
    IRPageViewController *pageViewController = [[IRPageViewController alloc] initWithTransitionStyle:transitionStyle
                                                                               navigationOrientation:orientation
                                                                                             options:nil];
    pageViewController.delegate = self;
    pageViewController.dataSource = self;
    pageViewController.view.backgroundColor = [UIColor clearColor];
     pageViewController.doubleSided = (UIPageViewControllerTransitionStylePageCurl == transitionStyle);
    if (pageViewController.scrollView) {
        pageViewController.scrollView.delegate = self;
    }
    
    if (self.pageViewController.parentViewController) {
        [self.pageViewController willMoveToParentViewController:nil];
        [self.pageViewController removeFromParentViewController];
        self.pageViewController.scrollView.delegate = nil;
    }
    
    [self addChildViewController:pageViewController];
    [pageViewController didMoveToParentViewController:self];
    [self.view addSubview:pageViewController.view];
    
    if (self.changeNavigationOrientationByUser && self.readerSettingView) {
        [self.view bringSubviewToFront:self.readerSettingView];
    }
    
    IRReadingViewController *readVc = nil;
    if (self.changeNavigationOrientationByUser) {
        self.changeNavigationOrientationByUser = NO;
        readVc = [self currentReadingViewController];
        self.pageViewController.gestureRecognizerShouldBegin = YES;
    } else {
        if (self.chapterSelectIndex < self.chapters.count) {
            IRChapterModel *selectChapter = [self.chapters safeObjectAtIndex:self.chapterSelectIndex];
            if ([selectChapter isKindOfClass:[IRChapterModel class]]) {
                self.currentPage = [selectChapter.pages safeObjectAtIndex:self.pageSelectIndex returnFirst:YES];
            }
        }
        
        IRDebugLog(@"Current chapter index: %zd page index: %zd", self.currentPage.chapterIndex, self.currentPage.pageIndex);
        readVc = [self readingViewControllerWithPageModel:self.currentPage creatIfNoExist:YES];
        
        if (!self.currentPage) {
            self.reloadDataIfNeeded = YES;
            self.pageViewController.gestureRecognizerShouldBegin = NO;
            [self parseTocRefrenceToChapterModel:[self.book.flatTableOfContents safeObjectAtIndex:self.chapterSelectIndex] atIndext:self.pageSelectIndex pendingReloadReadingVc:readVc toBefore:NO];
        }
    }
    
    [pageViewController setViewControllers:@[readVc]
                                 direction:UIPageViewControllerNavigationDirectionForward
                                  animated:NO
                                completion:nil];
    
    self.pageViewController = pageViewController;
}

- (void)cacheReadingViewController:(UIViewController *)readingVc
{
    if ([readingVc isKindOfClass:[IRReadingViewController class]]) {
        [self.childViewControllersCache addObject:(IRReadingViewController *)readingVc];
    }
}

- (IRReadingViewController *)readingViewControllerWithPageModel:(IRPageModel *)pageModel creatIfNoExist:(BOOL)flag
{
    IRReadingViewController *readVc = nil;
    if (self.childViewControllersCache.count) {
        readVc = self.childViewControllersCache.lastObject;
        [self.childViewControllersCache removeLastObject];
    } else {
        if (flag) {
            readVc = [[IRReadingViewController alloc] init];
        }
    }
    
    if (readVc) {
        readVc.view.frame = self.pageViewController.view.bounds;
        readVc.pageModel = pageModel;
    }
    
    IRDebugLog(@"Next readingViewController: %@", readVc);
    return readVc;
}

- (void)parseTocRefrenceToChapterModel:(IRTocRefrence *)tocRefrence
                              atIndext:(NSUInteger)index
                pendingReloadReadingVc:(IRReadingViewController *)pendingVc
                              toBefore:(BOOL)toBefore
{
    self.pageViewController.gestureRecognizerShouldBegin = NO;
    if (!self.pageViewController.scrollView.isTracking &&
        !self.pageViewController.gestureRecognizerShouldBegin &&
        self.pageViewController.scrollView.userInteractionEnabled) {
        
        self.pageViewController.scrollView.userInteractionEnabled = NO;
    }
    
    IR_WEAK_SELF
    dispatch_async(self.chapter_parse_serial_queue, ^{
        IRChapterModel *chapterModel = [IRChapterModel modelWithTocRefrence:tocRefrence chapterIndex:index];
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf parseChapterCompletedWithChater:chapterModel pendingReloadReadingVc:pendingVc toBefore:toBefore];
        });
    });
}

- (void)parseChapterCompletedWithChater:(IRChapterModel *)chapter
                 pendingReloadReadingVc:(IRReadingViewController *)pendingVc
                               toBefore:(BOOL)toBefore
{
    IRDebugLog(@"Chapter parse successed with index: %zd title: %@", chapter.chapterIndex, chapter.title);
    [self.chapters replaceObjectAtIndex:chapter.chapterIndex withObject:chapter];
    
    if (self.reloadDataIfNeeded) {
        if (toBefore) {
            pendingVc.pageModel = chapter.pages.lastObject;
        } else {
            pendingVc.pageModel = [chapter.pages safeObjectAtIndex:self.pageSelectIndex returnFirst:YES];
        }
        
        self.currentPage = pendingVc.pageModel;
        IRDebugLog(@"Current chapter index: %zd page index: %zd", self.currentPage.chapterIndex, self.currentPage.pageIndex);
        self.reloadDataIfNeeded = NO;
    }
    
    self.pageViewController.view.userInteractionEnabled = YES;
    self.pageViewController.gestureRecognizerShouldBegin = YES;
}

- (IRReadingViewController *)currentReadingViewController
{
    return self.pageViewController.childViewControllers.firstObject;
}

- (void)updateReaderSettingViewStateWithAnimated:(BOOL)animated completion:(void (^)(void))completion
{
    self.shouldHideStatusBar = !self.shouldHideStatusBar;
    
    [UIView animateWithDuration:(animated ? 0.25 : 0) animations:^{
        [self setNeedsStatusBarAppearanceUpdate];
    } completion:^(BOOL finished) {
        if (completion) {
            completion();
        }
    }];
    
    [self.navigationController setNavigationBarHidden:self.shouldHideStatusBar animated:animated];
    
    if (!self.shouldHideStatusBar) {
        IRReaderSettingView *settingView = [IRReaderSettingView readerSettingView];
        settingView.delegate = self;
        [settingView showInView:self.view animated:YES];
        self.readerSettingView = settingView;
    }
}

#pragma mark - ReaderSettingViewDeletage

- (void)readerSettingViewWillDisappear:(IRReaderSettingView *)readerSettingView
{
    [self updateReaderSettingViewStateWithAnimated:YES completion:nil];
}

- (void)readerSettingViewDidClickVerticalButton:(IRReaderSettingView *)readerSettingView
{
    self.changeNavigationOrientationByUser = YES;
    [IR_READER_CONFIG updateReaderPageNavigationOrientation:ReaderPageNavigationOrientationVertical];
    [self updatePageViewControllerWithNavigationOrientation:UIPageViewControllerNavigationOrientationVertical
                                            transitionStyle:UIPageViewControllerTransitionStylePageCurl];
}

- (void)readerSettingViewDidClickHorizontalButton:(IRReaderSettingView *)readerSettingView
{
    self.changeNavigationOrientationByUser = YES;
    [IR_READER_CONFIG updateReaderPageNavigationOrientation:ReaderPageNavigationOrientationHorizontal];
    [self updatePageViewControllerWithNavigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                            transitionStyle:UIPageViewControllerTransitionStylePageCurl];
}

- (void)readerSettingViewDidChangedTextSizeMultiplier:(CGFloat)textSizeMultiplier
{
    self.chapters = nil;
    self.reloadDataIfNeeded = YES;
    self.pageSelectIndex = self.currentPage.pageIndex;
    [self parseTocRefrenceToChapterModel:[self.book.flatTableOfContents safeObjectAtIndex:self.currentPage.chapterIndex]
                                atIndext:self.currentPage.chapterIndex
                  pendingReloadReadingVc:[self currentReadingViewController]
                                toBefore:NO];
}

- (void)readerSettingViewDidClickNightButton:(IRReaderSettingView *)readerSettingView
{
    IR_READER_CONFIG.isNightMode = YES;
    [self currentReadingViewController].view.backgroundColor = IR_READER_CONFIG.readerBgColor;
    [self readerSettingViewDidChangedTextSizeMultiplier:IR_READER_CONFIG.textSizeMultiplier];
}

- (void)readerSettingViewDidClickSunButton:(IRReaderSettingView *)readerSettingView
{
    IR_READER_CONFIG.isNightMode = NO;
    [self currentReadingViewController].view.backgroundColor = IR_READER_CONFIG.readerBgColor;;
    [self readerSettingViewDidChangedTextSizeMultiplier:IR_READER_CONFIG.textSizeMultiplier];
}

- (void)readerSettingViewDidSelectBackgroundColor:(UIColor *)bgColor
{
    [self currentReadingViewController].view.backgroundColor = bgColor;
    UIColor *textColor = [IR_READER_CONFIG readerTextColorWithBgColor:bgColor];
    if (!CGColorEqualToColor(IR_READER_CONFIG.readerTextColor.CGColor, textColor.CGColor)) {
        IR_READER_CONFIG.readerTextColor = textColor;
        [self readerSettingViewDidChangedTextSizeMultiplier:IR_READER_CONFIG.textSizeMultiplier];
    }
}

#pragma mark - BookChapterListControllerDelegate

- (void)bookChapterListControllerDidSelectChapterAtIndex:(NSUInteger)index
{
    [self selectChapterAtIndex:index];
    self.fromChapterListView = YES;
    [self.readerSettingView dismissWithAnimated:NO];
}

#pragma mark - IRReaderNavigationViewDelegate

- (void)readerNavigationViewDidClickChapterListButton:(IRReaderNavigationView *)aView
{
    BookChapterListController *chapterVc = [[BookChapterListController alloc] init];
    chapterVc.delegate = self;
    chapterVc.chapterList = self.book.flatTableOfContents;
    chapterVc.selectChapterIndex = self.currentPage.chapterIndex;
    [self.navigationController pushViewController:chapterVc animated:YES];
}

- (void)readerNavigationViewDidClickCloseButton:(IRReaderNavigationView *)aView
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIPageViewController ScrollView

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    self.scrollBeginOffset = scrollView.contentOffset;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (!self.isScrollToNext && scrollView.contentOffset.x > self.scrollBeginOffset.x) {
        self.isScrollToNext = YES;
    } else if (self.isScrollToNext && scrollView.contentOffset.x < self.scrollBeginOffset.x) {
        self.isScrollToNext = NO;
    }
    
    if (!scrollView.isTracking &&
        !self.pageViewController.gestureRecognizerShouldBegin &&
        self.pageViewController.scrollView.userInteractionEnabled) {
        
        self.pageViewController.scrollView.userInteractionEnabled = NO;
    }
}

#pragma mark - UIPageViewController

- (void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray<UIViewController *> *)pendingViewControllers
{
    self.pageViewController.gestureRecognizerShouldBegin = NO;

    if (UIPageViewControllerTransitionStyleScroll == pageViewController.transitionStyle) {
        
        IRReadingViewController *pending = (IRReadingViewController *)pendingViewControllers.firstObject;
        IRPageModel *nextPage = nil;
        NSUInteger pageIndex  = self.currentPage.pageIndex;
        NSUInteger chapterIndex = self.currentPage.chapterIndex;
        
        if (self.isScrollToNext) {

            IRChapterModel *currentChapter = [self.chapters safeObjectAtIndex:chapterIndex];
            if (pageIndex < currentChapter.pages.count - 1) {
                pageIndex++;
                nextPage = [currentChapter.pages safeObjectAtIndex:pageIndex];
            } else {
                if (chapterIndex < self.chapterCount - 1) {
                    chapterIndex++;
                    IRChapterModel *chapter = [self.chapters safeObjectAtIndex:chapterIndex];
                    if ([chapter isKindOfClass:[NSNull class]]) {
                        self.reloadDataIfNeeded = YES;
                        [self parseTocRefrenceToChapterModel:[self.book.flatTableOfContents safeObjectAtIndex:chapterIndex]
                                                    atIndext:chapterIndex pendingReloadReadingVc:pending toBefore:NO];
                    } else {
                        nextPage = chapter.pages.firstObject;
                    }
                }
            }
        } else {

            IRChapterModel *chapter = nil;
            if (pageIndex > 0) {
                pageIndex--;
                chapter = [self.chapters safeObjectAtIndex:chapterIndex];
                nextPage = [chapter.pages safeObjectAtIndex:pageIndex];
            } else {

                if (chapterIndex > 0) {
                    chapterIndex--;
                    chapter = [self.chapters safeObjectAtIndex:chapterIndex];
                    if ([chapter isKindOfClass:[NSNull class]]) {
                        self.reloadDataIfNeeded = YES;
                        [self parseTocRefrenceToChapterModel:[self.book.flatTableOfContents safeObjectAtIndex:chapterIndex]
                                                    atIndext:chapterIndex pendingReloadReadingVc:pending toBefore:YES];
                    } else {
                        nextPage = chapter.pages.lastObject;
                    }
                }
            }
        }
        
        if (nextPage) {
            self.nextPage = nextPage;
        }
        pending.pageModel = nextPage;
    }
    
    IRDebugLog(@"pageViewController childViewControllers: %@ pendingViewControllers: %@", pageViewController.childViewControllers, pendingViewControllers);
}

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed
{
    if (!completed) {
        self.reloadDataIfNeeded = NO;
    }
    
    if (completed && previousViewControllers.count) {
         [self cacheReadingViewController:previousViewControllers.firstObject];
    }
    
    if (completed && self.nextPage) {
        self.currentPage = self.nextPage;
    }
    IRDebugLog(@"Current chapter index: %zd page index: %zd", self.currentPage.chapterIndex, self.currentPage.pageIndex);
    
    self.nextPage = nil;
    if (!self.reloadDataIfNeeded) {
        self.pageViewController.scrollView.userInteractionEnabled = YES;
        self.pageViewController.gestureRecognizerShouldBegin = YES;
    }
    
    IRDebugLog(@"previousViewControllers: %@", previousViewControllers);
}

- (nullable UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    IRPageModel *beforePage = nil;
    IRChapterModel *chapter = nil;
    IRReadingViewController *beforeReadVc = nil;
    
    if (UIPageViewControllerTransitionStylePageCurl == pageViewController.transitionStyle) {
        
        if ([viewController isKindOfClass:[IRReadingViewController class]]) {
            self.currentReadingViewController = (IRReadingViewController *)viewController;
            NSUInteger pageIndex = self.currentReadingViewController.pageModel.pageIndex;
            NSUInteger chapterIndex = self.currentReadingViewController.pageModel.chapterIndex;
            
            if (pageIndex > 0) {
                pageIndex--;
                chapter = [self.chapters safeObjectAtIndex:chapterIndex];
                beforePage = [chapter.pages safeObjectAtIndex:pageIndex];
            } else {
                
                if (chapterIndex > 0) {
                    chapterIndex--;
                    chapter = [self.chapters safeObjectAtIndex:chapterIndex];
                    if (![chapter isKindOfClass:[NSNull class]]) {
                        beforePage = chapter.pages.lastObject;
                    }
                }
            }
            
            beforeReadVc = [self readingViewControllerWithPageModel:beforePage creatIfNoExist:YES];
            if (!beforePage) {
                [beforeReadVc dismissChapterLoadingHUD];
            }
            
            IRReadingBackViewController *backViewController = [[IRReadingBackViewController alloc] init];
            backViewController.view.frame = pageViewController.view.bounds;
            [backViewController updateWithViewController:beforeReadVc];
            return backViewController;
        }
        
    } else {
        self.currentReadingViewController = (IRReadingViewController *)viewController;
    }
    
    NSUInteger pageIndex = self.currentReadingViewController.pageModel.pageIndex;
    NSUInteger chapterIndex = self.currentReadingViewController.pageModel.chapterIndex;
    
    if (pageIndex > 0) {
        pageIndex--;
        chapter = [self.chapters safeObjectAtIndex:chapterIndex];
        beforePage = [chapter.pages safeObjectAtIndex:pageIndex];
    } else {
        
        if (chapterIndex > 0) {
            chapterIndex--;
            chapter = [self.chapters safeObjectAtIndex:chapterIndex];
            if ([chapter isKindOfClass:[NSNull class]]) {
                self.reloadDataIfNeeded = YES;
            } else {
                beforePage = chapter.pages.lastObject;
            }
        } else {
            return nil;
        }
    }
    
    if (beforePage && UIPageViewControllerTransitionStylePageCurl == pageViewController.transitionStyle) {
        self.currentPage = beforePage;
    }
    
    IRDebugLog(@"BeforeViewController: %@", viewController);
    beforeReadVc = [self readingViewControllerWithPageModel:beforePage creatIfNoExist:YES];
    if (self.reloadDataIfNeeded) {
        [self parseTocRefrenceToChapterModel:[self.book.flatTableOfContents safeObjectAtIndex:chapterIndex]
                                    atIndext:chapterIndex pendingReloadReadingVc:beforeReadVc toBefore:YES];
    }
    
    return beforeReadVc;
}

- (nullable UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    if (UIPageViewControllerTransitionStylePageCurl == pageViewController.transitionStyle) {
        if ([viewController isKindOfClass:[IRReadingViewController class]]) {
            self.currentReadingViewController  = (IRReadingViewController *)viewController;
            IRReadingBackViewController *backViewController = [[IRReadingBackViewController alloc] init];
            backViewController.view.frame = pageViewController.view.bounds;
            [backViewController updateWithViewController:viewController];
            return backViewController;
        }
    } else {
        self.currentReadingViewController  = (IRReadingViewController *)viewController;
    }
    
    
    IRPageModel *afterPage = nil;
    IRReadingViewController *afterReadVc = nil;
    NSUInteger pageIndex = self.currentReadingViewController.pageModel.pageIndex;
    NSUInteger chapterIndex = self.currentReadingViewController.pageModel.chapterIndex;
    IRChapterModel *currentChapter = [self.chapters safeObjectAtIndex:chapterIndex];
    
    if (pageIndex < currentChapter.pages.count - 1) {
        pageIndex = pageIndex + 1;
        afterPage = [currentChapter.pages safeObjectAtIndex:pageIndex];
    } else {
        if (chapterIndex < self.chapterCount - 1) {
            chapterIndex++;
            id chapter = [self.chapters safeObjectAtIndex:chapterIndex];
            if ([chapter isKindOfClass:[NSNull class]]) {
                self.reloadDataIfNeeded = YES;
            } else {
                afterPage = [(IRChapterModel *)chapter pages].firstObject;
            }
        } else {
            return nil;
        }
    }
    
    if (afterPage && UIPageViewControllerTransitionStylePageCurl == pageViewController.transitionStyle) {
        self.currentPage = afterPage;
    }
    
    IRDebugLog(@"AfterViewController: %@", viewController);
    afterReadVc = [self readingViewControllerWithPageModel:afterPage creatIfNoExist:YES];
    
    if (self.reloadDataIfNeeded) {
        self.pageSelectIndex = 0;
        [self parseTocRefrenceToChapterModel:[self.book.flatTableOfContents safeObjectAtIndex:chapterIndex]
                                    atIndext:chapterIndex pendingReloadReadingVc:afterReadVc toBefore:NO];
    }
    
    return afterReadVc;
}

#pragma mark - Public

- (instancetype)initWithBook:(IREpubBook *)book
{
    if (self = [super init]) {
        self.book = book;
        self.chapterCount = book.flatTableOfContents.count;
        self.chapter_parse_serial_queue = dispatch_queue_create("ir_chapter_parse_serial_queue", DISPATCH_QUEUE_SERIAL);
    }

    return self;
}

- (void)selectChapterAtIndex:(NSUInteger)chapterIndex
{
    [self selectChapterAtIndex:chapterIndex pageAtIndex:0];
}

- (void)selectChapterAtIndex:(NSUInteger)chapterIndex pageAtIndex:(NSUInteger)pageInadex
{
    self.chapterSelectIndex = chapterIndex;
    self.pageSelectIndex = pageInadex;
    
    if ([self isViewLoaded]) {
        if (chapterIndex < self.chapters.count) {
            IRChapterModel *select = [self.chapters safeObjectAtIndex:chapterIndex];
            if ([select isKindOfClass:[NSNull class]]) {
                self.reloadDataIfNeeded = YES;
                [self parseTocRefrenceToChapterModel:[self.book.flatTableOfContents safeObjectAtIndex:chapterIndex] atIndext:self.chapterSelectIndex pendingReloadReadingVc:[self currentReadingViewController] toBefore:NO];
            } else {
                IRReadingViewController *currentVc = [self currentReadingViewController];
                currentVc.pageModel = [select.pages safeObjectAtIndex:pageInadex returnFirst:YES];
                self.currentPage = currentVc.pageModel;
            }
        } else {
            if (chapterIndex < self.chapterCount) {
                self.reloadDataIfNeeded = YES;
            } else {
                IRDebugLog(@"Select chapter index is not exist:%zd chapterCount: %zd", chapterIndex, self.chapterCount);
            }
        }
    } else {
        if (chapterIndex >= self.chapterCount) {
            self.chapterSelectIndex = 0;
            IRDebugLog(@"Select chapter index is not exist:%zd chapterCount: %zd", chapterIndex, self.chapterCount);
        }
    }
}

@end
