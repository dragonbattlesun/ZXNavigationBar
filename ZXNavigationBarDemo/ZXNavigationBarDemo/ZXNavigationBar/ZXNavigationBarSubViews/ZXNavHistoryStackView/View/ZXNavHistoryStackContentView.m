//
//  ZXNavHistoryStackContentView.m
//  ZXNavigationBar
//
//  Created by 李兆祥 on 2020/12/22.
//  Copyright © 2020 ZXLee. All rights reserved.
//  https://github.com/SmileZXLee/ZXNavigationBar
//  V1.4.1

#import "ZXNavHistoryStackContentView.h"
#import "ZXNavHistoryStackCell.h"

#import "ZXNavigationBarDefine.h"
#import "ZXNavigationBarGeometry.h"
#import "UIView+ZXNavFrameExtension.h"

#import <UIKit/UIFeedbackGenerator.h>
#import <math.h>
static NSString *historyStackViewCellReuseIdentifier = @"ZXNavHistoryStackCell";
static BOOL ZXHistoryHasFiniteRect(CGRect rect) {
    return isfinite(rect.origin.x) && isfinite(rect.origin.y) &&
        isfinite(rect.size.width) && isfinite(rect.size.height) &&
        rect.size.width >= 0 && rect.size.height >= 0;
}
static CGFloat ZXHistorySafeInset(CGFloat value, CGFloat available) {
    return isfinite(value) ? MIN(MAX(0, value), available) : 0;
}
static UIWindow *ZXHistoryWindowForContainer(UIView *container) {
    return [container isKindOfClass:UIWindow.class] ? (UIWindow *)container : container.window;
}
@interface ZXNavHistoryStackContentView()<UICollectionViewDelegate,UICollectionViewDataSource>
@property (strong, nonatomic) UIView *coverView;
@property (assign, nonatomic) BOOL isShowed;
@property (strong, nonatomic) ZXNavHistoryStackModel *selectedHistoryStackModel;
@property (weak, nonatomic) UIView *containerView;
@property (weak, nonatomic) UIView *anchorView;
@property (assign, nonatomic) CGFloat anchorOffsetX;
@property (assign, nonatomic) CGRect lastAnchorRect;
@property (assign, nonatomic) BOOL hasValidAnchorRect;
@end
@implementation ZXNavHistoryStackContentView

#pragma mark - Init
- (instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if(self){
        [self setUp];
    }
    return self;
}

- (void)setUp{
    [self addSubview:self.coverView];
    [self addSubview:self.zx_historyStackView];
    self.zx_historyStackView.delegate = self;
    self.zx_historyStackView.dataSource = self;
    [self.zx_historyStackView registerClass:[ZXNavHistoryStackCell class] forCellWithReuseIdentifier:historyStackViewCellReuseIdentifier];
    self.coverView.userInteractionEnabled = YES;
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(coverViewTouch)];
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(coverViewTouch)];
    [self.coverView addGestureRecognizer:panGestureRecognizer];
    [self.coverView addGestureRecognizer:tapGestureRecognizer];
}

- (void)layoutSubviews{
    [super layoutSubviews];
    if (self.containerView && self.superview == self.containerView && ZXHistoryHasFiniteRect(self.containerView.bounds)) {
        self.frame = self.containerView.bounds;
    }
    self.coverView.frame = self.bounds;
    if(self.isShowed){
        [self updateHistoryStackViewFrameWithHide:NO];
    }
}

- (void)coverViewTouch{
    if(self.isShowed){
        [self zx_hide];
    }
}

- (instancetype)zx_show{
    // 旧入口不加载控制器的 view，也不访问进程级窗口。
    for (ZXNavHistoryStackModel *model in self.zx_historyStackArray) {
        UIViewController *controller = model.viewController;
        if (controller.isViewLoaded && controller.view.window) {
            return [self zx_showInContainerView:controller.view.window anchorView:nil];
        }
    }
    return self;
}

- (instancetype)zx_showInContainerView:(UIView *)containerView anchorView:(UIView *)anchorView {
    UIWindow *window = ZXHistoryWindowForContainer(containerView);
    if (!window || containerView == self || [containerView isDescendantOfView:self] ||
        !ZXHistoryHasFiniteRect(containerView.bounds)) { return self; }
    CGRect anchorRect = CGRectZero;
    if (anchorView) {
        if (anchorView.window != window) { return self; }
        anchorRect = [anchorView convertRect:anchorView.bounds toView:containerView];
        if (!ZXHistoryHasFiniteRect(anchorRect) || !isfinite(anchorView.frame.origin.x)) { return self; }
    }
    self.containerView = containerView;
    self.anchorView = anchorView;
    // 旧 left 是按钮父视图坐标中的 x 加调用方 offset；只保存 offset，布局时重新转换真实锚点。
    self.anchorOffsetX = anchorView ? self.zx_historyStackViewLeft - anchorView.frame.origin.x : 0;
    if (!isfinite(self.anchorOffsetX)) { self.anchorOffsetX = 0; }
    self.hasValidAnchorRect = NO;
    self.frame = containerView.bounds;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [containerView addSubview:self];
    self.coverView.frame = self.bounds;
    [self updateHistoryStackViewFrameWithHide:YES];
    self.isShowed = YES;
    [UIView animateWithDuration:0.2 animations:^{
        self.coverView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.05];
        [self updateHistoryStackViewFrameWithHide:NO];
    }];
    
    return self;
}

- (void)zx_hide{
    self.isShowed = NO;
    [UIView animateWithDuration:0.15 animations:^{
        self.coverView.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
        [self updateHistoryStackViewFrameWithHide:YES];
    }completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (void)updateHistoryStackViewFrameWithHide:(BOOL)isHide{
    if (!ZXHistoryHasFiniteRect(self.bounds)) { return; }
    UIEdgeInsets insets = self.safeAreaInsets;
    CGFloat left = ZXHistorySafeInset(insets.left, self.bounds.size.width);
    CGFloat right = ZXHistorySafeInset(insets.right, self.bounds.size.width - left);
    CGFloat top = ZXHistorySafeInset(insets.top, self.bounds.size.height);
    CGFloat bottom = ZXHistorySafeInset(insets.bottom, self.bounds.size.height - top);
    CGRect safe = UIEdgeInsetsInsetRect(self.bounds, UIEdgeInsetsMake(top, left, bottom, right));
    UIView *anchor = self.anchorView;
    // 离窗、换窗或转场的非有限坐标只保留上次有效锚点，并继续按当前安全区钳制。
    if (anchor.window && anchor.window == self.window && self.window == ZXHistoryWindowForContainer(self.containerView)) {
        CGRect rect = [anchor convertRect:anchor.bounds toView:self];
        if (ZXHistoryHasFiniteRect(rect)) {
            self.lastAnchorRect = rect;
            self.hasValidAnchorRect = YES;
        }
    }
    CGFloat x = self.hasValidAnchorRect ? self.lastAnchorRect.origin.x + self.anchorOffsetX : self.zx_historyStackViewLeft;
    CGFloat y = self.hasValidAnchorRect ? self.lastAnchorRect.origin.y : CGRectGetMinY(safe);
    if (!isfinite(x)) { x = CGRectGetMinX(safe); }
    if (!isfinite(y)) { y = CGRectGetMinY(safe); }
    y = MIN(MAX(y, CGRectGetMinY(safe)), CGRectGetMaxY(safe));
    CGFloat height = MIN(self.zx_historyStackArray.count * ZXNavHistoryStackCellHeight, MAX(0, CGRectGetMaxY(safe) - y));
    CGFloat width = MIN(ZXNavHistoryStackViewWidth, safe.size.width);
    CGRect preferredFrame = CGRectMake(x, y, width, height);
    CGRect contentBand = CGRectMake(CGRectGetMinX(safe), y, CGRectGetWidth(safe), height);
    NSArray<NSValue *> *reservedFrames = ZXNavigationBarActiveReservedRegionFramesForView(self);
    NSArray<NSValue *> *segments = ZXNavigationBarAvailableHorizontalSegments(
        contentBand,
        UIEdgeInsetsZero,
        reservedFrames
    );
    CGRect frame = ZXNavigationBarFitHorizontalFrame(preferredFrame, segments);
    if (segments.count == 0 && height > 0) {
        // tabletop / tent 的横向 division 可能占满整行；浮层改在二维可用区中选择上方或下方，
        // 不能沿用纯水平算法塌成 0 宽。
        frame = ZXNavigationBarFitHorizontalFrame(preferredFrame, @[[NSValue valueWithCGRect:safe]]);
        NSArray<NSValue *> *verticalSegments = ZXNavigationBarAvailableVerticalSegments(
            safe,
            UIEdgeInsetsZero,
            reservedFrames
        );
        CGFloat minimumUsableHeight = MIN(ZXNavHistoryStackCellHeight, height);
        NSMutableArray<NSValue *> *usableSegments = [NSMutableArray array];
        for (NSValue *value in verticalSegments) {
            if (CGRectGetHeight(value.CGRectValue) >= minimumUsableHeight) {
                [usableSegments addObject:value];
            }
        }
        frame = ZXNavigationBarFitVerticalFrame(frame, usableSegments.count > 0 ? usableSegments : verticalSegments);
    }
    if (isHide) {
        frame = CGRectMake(MIN(CGRectGetMinX(frame) + 20, CGRectGetMaxX(frame)),
                           MIN(y + ZXNavHistoryStackCellHeight / 2, CGRectGetMaxY(safe)), 0, 0);
    }
    if (!CGSizeEqualToSize(frame.size, self.zx_historyStackView.frame.size)) {
        [self.zx_historyStackView.collectionViewLayout invalidateLayout];
    }
    self.zx_historyStackView.frame = frame;
}

#pragma mark - UICollectionViewDelegate
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath{
    return CGSizeMake(self.zx_historyStackView.frame.size.width, ZXNavHistoryStackCellHeight);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    ZXNavHistoryStackModel *historyStackModel = self.zx_historyStackArray[indexPath.row];
    [self doPopViewController:historyStackModel];
}

#pragma mark - UICollectionViewDataSource
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return self.zx_historyStackArray.count;
}
 
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    ZXNavHistoryStackCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:historyStackViewCellReuseIdentifier forIndexPath:indexPath];
    cell.historyStackViewStyle = self.zx_historyStackViewStyle;
    cell.historyStackModel = self.zx_historyStackArray[indexPath.row];
    return cell;
}

#pragma mark - Private
- (void)handlePanGestureWithPoint:(CGPoint)point{
    if(point.x > CGRectGetMaxX(self.zx_historyStackView.frame) || point.y > CGRectGetMaxY(self.zx_historyStackView.frame)){
        if(self.selectedHistoryStackModel){
            self.selectedHistoryStackModel.isSelected = NO;
            self.selectedHistoryStackModel = nil;
            [self.zx_historyStackView reloadData];
        }
    }else{
        if(self.selectedHistoryStackModel){
            self.selectedHistoryStackModel.isSelected = NO;
        }
        NSIndexPath *indexPath = [self.zx_historyStackView indexPathForItemAtPoint:point];
        ZXNavHistoryStackModel *historyStackModel = self.zx_historyStackArray[indexPath.row];
        if(indexPath && !(self.selectedHistoryStackModel && self.selectedHistoryStackModel == historyStackModel)){
            historyStackModel.isSelected = YES;
            [self.zx_historyStackView reloadData];
            self.selectedHistoryStackModel = historyStackModel;
            if (@available(iOS 10.0, *)){
                UIImpactFeedbackGenerator *impactFeedbackGenerator = [[UIImpactFeedbackGenerator alloc]initWithStyle:UIImpactFeedbackStyleLight];
                [impactFeedbackGenerator impactOccurred];
            }
        }
    }
}

- (void)handlePanGestureEnd{
    [self doPopViewController:self.selectedHistoryStackModel];
}


- (void)doPopViewController:(ZXNavHistoryStackModel *)historyStackModel{
    if(historyStackModel && historyStackModel.viewController && historyStackModel.viewController.navigationController){
        [historyStackModel.viewController.navigationController popToViewController:historyStackModel.viewController animated:YES];
        [self zx_hide];
    }
}

#pragma mark - LazyLoad
- (ZXNavHistoryStackView *)zx_historyStackView{
    if(!_zx_historyStackView){
        UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
        flowLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
        flowLayout.minimumInteritemSpacing = 0;
        flowLayout.minimumLineSpacing = 0;
        _zx_historyStackView = [[ZXNavHistoryStackView alloc]initWithFrame:CGRectZero collectionViewLayout:flowLayout];
        _zx_historyStackView.backgroundColor = [UIColor whiteColor];
        _zx_historyStackView.clipsToBounds = YES;
        _zx_historyStackView.layer.cornerRadius = 12;
        if(self.zx_historyStackViewStyle == ZXNavHistoryStackViewStyleLight){
            _zx_historyStackView.backgroundColor = ZXNavHistoryStackViewStyleLightBackgroundColor;
        }else{
            _zx_historyStackView.backgroundColor = ZXNavHistoryStackViewStyleDarkBackgroundColor;
        }
        
    }
    return _zx_historyStackView;
}

- (UIView *)coverView{
    if(!_coverView){
        _coverView = [[UIView alloc]init];
    }
    return _coverView;
}

- (void)setZx_historyStackArray:(NSMutableArray<ZXNavHistoryStackModel *> *)zx_historyStackArray{
    _zx_historyStackArray = zx_historyStackArray;
    if(zx_historyStackArray.count){
        ZXNavHistoryStackModel *firstHistoryStackModel = zx_historyStackArray.firstObject;
        ZXNavHistoryStackModel *lastHistoryStackModel = zx_historyStackArray.lastObject;
        firstHistoryStackModel.isSelected = YES;
        self.selectedHistoryStackModel = firstHistoryStackModel;
        lastHistoryStackModel.isLast = YES;
    }
}

- (void)setZx_historyStackViewStyle:(ZXNavHistoryStackViewStyle)zx_historyStackViewStyle{
    _zx_historyStackViewStyle = zx_historyStackViewStyle;
    [self.zx_historyStackView reloadData];
}

- (void)setZx_historyStackViewLeft:(CGFloat)zx_historyStackViewLeft{
    _zx_historyStackViewLeft = zx_historyStackViewLeft;
    self.zx_historyStackView.zx_x = zx_historyStackViewLeft;
}

@end
