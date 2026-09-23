//
//  DemoXibViewController.m
//  ZXNavigationBarDemo
//
//  Created by 李兆祥 on 2020/3/10.
//  Copyright © 2020 ZXLee. All rights reserved.
//

#import "DemoXibViewController.h"
#import "DemoSystemBarViewController.h"
#import "ZXNavigationBarGeometry.h"
#import <math.h>

@interface DemoSettingRowLayout : NSObject
@property (weak, nonatomic) UIView *row;
@property (weak, nonatomic) UILabel *label;
@property (weak, nonatomic) UISwitch *toggle;
@property (weak, nonatomic) NSLayoutConstraint *leadingConstraint;
@property (weak, nonatomic) NSLayoutConstraint *trailingConstraint;
@property (assign, nonatomic) CGFloat defaultLeading;
@property (assign, nonatomic) CGFloat defaultTrailing;
@property (assign, nonatomic) CGFloat defaultHeight;
@end

@implementation DemoSettingRowLayout
@end

@interface DemoXibViewController () <UIScrollViewDelegate>
///是否禁止pop操作
@property(assign, nonatomic)BOOL disablePop;
@property(strong, nonatomic)NSArray<DemoSettingRowLayout *> *settingRowLayouts;
@property(weak, nonatomic)UISwitch *backgroundColorSwitch;
@property(strong, nonatomic)UILabel *geometryProbe;
@property(strong, nonatomic)UIScrollView *settingsScrollView;
@end

@implementation DemoXibViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //设置导航栏标题
    self.title = @"ZXNavigationBar";
    
    //设置最右侧的Button的图片和点击回调
    [self zx_setRightBtnWithImgName:@"set_icon" clickedBlock:^(UIButton * _Nonnull btn) {
        NSLog(@"点击了最右侧的Button");
    }];
    
    //最左侧的按钮添加”返回“文字，当当前控制器不是第0个的时候，ZXNavigationBar会自动显示返回图片，且点击返回上一个控制器
    [self.zx_navLeftBtn setTitle:@"返回" forState:UIControlStateNormal];
    
    __weak typeof(self) weakSelf = self;
    self.zx_handlePopBlock = ^BOOL(ZXNavigationBarController * _Nonnull viewController, ZXNavPopBlockFrom popBlockFrom) {
        return !weakSelf.disablePop;
    };

    self.zx_navRightBtn.accessibilityIdentifier = @"demo.property.navigation.settings";
    self.zx_navRightBtn.accessibilityLabel = @"Navigation settings";
    self.settingRowLayouts = [self makeSettingRowLayouts];
    [self embedSettingRowsInScrollView];
    [self configurePropertyPageAccessibility];
    if ([[NSProcessInfo processInfo].arguments containsObject:@"ZXNavigationBarGeometryUITests"]) {
        [self setUpGeometryProbe];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutSettingsScrollView];
    [self updateSettingRowsForReservedRegions];
    [self updateGeometryProbe];
}

- (NSArray<DemoSettingRowLayout *> *)makeSettingRowLayouts {
    NSMutableArray<DemoSettingRowLayout *> *layouts = [NSMutableArray array];
    for (UIView *row in self.view.subviews) {
        UILabel *label = nil;
        UISwitch *toggle = nil;
        for (UIView *subview in row.subviews) {
            if (!label && [subview isKindOfClass:UILabel.class]) {
                label = (UILabel *)subview;
            } else if (!toggle && [subview isKindOfClass:UISwitch.class]) {
                toggle = (UISwitch *)subview;
            }
        }
        if (!label || !toggle) {
            continue;
        }

        NSLayoutConstraint *leadingConstraint = nil;
        NSLayoutConstraint *trailingConstraint = nil;
        for (NSLayoutConstraint *constraint in row.constraints) {
            if (constraint.firstItem == label && constraint.firstAttribute == NSLayoutAttributeLeading &&
                constraint.secondItem == row && constraint.secondAttribute == NSLayoutAttributeLeading) {
                leadingConstraint = constraint;
            }
            if (constraint.firstItem == row && constraint.firstAttribute == NSLayoutAttributeTrailing &&
                constraint.secondItem == toggle && constraint.secondAttribute == NSLayoutAttributeTrailing) {
                trailingConstraint = constraint;
            }
        }
        if (!leadingConstraint || !trailingConstraint) {
            continue;
        }

        label.lineBreakMode = NSLineBreakByTruncatingTail;
        [label setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh - 1
                                             forAxis:UILayoutConstraintAxisHorizontal];
        NSLayoutConstraint *spacing = [label.trailingAnchor constraintLessThanOrEqualToAnchor:toggle.leadingAnchor constant:-8.0];
        spacing.priority = UILayoutPriorityRequired - 1;
        spacing.active = YES;

        DemoSettingRowLayout *layout = [DemoSettingRowLayout new];
        layout.row = row;
        layout.label = label;
        layout.toggle = toggle;
        layout.leadingConstraint = leadingConstraint;
        layout.trailingConstraint = trailingConstraint;
        layout.defaultLeading = leadingConstraint.constant;
        layout.defaultTrailing = trailingConstraint.constant;
        layout.defaultHeight = MAX(1, CGRectGetHeight(row.bounds));
        [layouts addObject:layout];
    }
    return [layouts sortedArrayUsingComparator:^NSComparisonResult(DemoSettingRowLayout *left, DemoSettingRowLayout *right) {
        CGFloat leftY = CGRectGetMinY(left.row.frame);
        CGFloat rightY = CGRectGetMinY(right.row.frame);
        return leftY < rightY ? NSOrderedAscending : leftY > rightY ? NSOrderedDescending : NSOrderedSame;
    }];
}

- (void)embedSettingRowsInScrollView {
    if (self.settingRowLayouts.count == 0) {
        return;
    }

    NSSet<UIView *> *rows = [NSSet setWithArray:[self.settingRowLayouts valueForKey:@"row"]];
    NSMutableArray<NSLayoutConstraint *> *externalConstraints = [NSMutableArray array];
    for (NSLayoutConstraint *constraint in self.view.constraints) {
        if ([rows containsObject:constraint.firstItem] || [rows containsObject:constraint.secondItem]) {
            [externalConstraints addObject:constraint];
        }
    }
    [NSLayoutConstraint deactivateConstraints:externalConstraints];

    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    scrollView.accessibilityIdentifier = @"demo.property.scroll";
    scrollView.alwaysBounceVertical = YES;
    scrollView.directionalLockEnabled = YES;
    scrollView.delegate = self;
    if (@available(iOS 11.0, *)) {
        scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    if (self.zx_navBar.superview == self.view) {
        [self.view insertSubview:scrollView belowSubview:self.zx_navBar];
    } else {
        [self.view addSubview:scrollView];
    }
    for (DemoSettingRowLayout *layout in self.settingRowLayouts) {
        layout.row.translatesAutoresizingMaskIntoConstraints = YES;
        [scrollView addSubview:layout.row];
    }
    self.settingsScrollView = scrollView;
}

- (void)layoutSettingsScrollView {
    if (!self.settingsScrollView) {
        return;
    }

    UIEdgeInsets safeAreaInsets = ZXNavigationBarSafeAreaInsetsForView(self.view);
    CGFloat minimumY = CGRectGetMinY(self.view.bounds) + safeAreaInsets.top;
    CGFloat navigationBottom = self.zx_navBar.hidden ? minimumY : CGRectGetMaxY(self.zx_navBar.frame);
    CGFloat scrollY = MAX(minimumY, navigationBottom);
    CGFloat scrollBottom = CGRectGetMaxY(self.view.bounds) - safeAreaInsets.bottom;
    CGFloat scrollWidth = MAX(0, CGRectGetWidth(self.view.bounds) - safeAreaInsets.left - safeAreaInsets.right);
    self.settingsScrollView.frame = CGRectMake(
        CGRectGetMinX(self.view.bounds) + safeAreaInsets.left,
        scrollY,
        scrollWidth,
        MAX(0, scrollBottom - scrollY)
    );

    CGFloat rowY = 0;
    for (DemoSettingRowLayout *layout in self.settingRowLayouts) {
        layout.row.frame = CGRectMake(0, rowY, scrollWidth, layout.defaultHeight);
        rowY += layout.defaultHeight;
    }
    self.settingsScrollView.contentSize = CGSizeMake(scrollWidth, rowY);
}

- (void)configurePropertyPageAccessibility {
    NSArray<NSString *> *identifiers = @[
        @"demo.property.backgroundColor.switch",
        @"demo.property.backgroundImage.switch",
        @"demo.property.tintColor.switch",
        @"demo.property.largeTitle.switch",
        @"demo.property.statusBarStyle.switch",
        @"demo.property.itemSize.switch",
        @"demo.property.itemMargin.switch",
        @"demo.property.gradient.switch",
        @"demo.property.systemNavigation.switch",
        @"demo.property.secondaryAction.switch",
        @"demo.property.disablePop.switch"
    ];
    NSArray<NSString *> *labels = @[
        @"Use orange navigation background",
        @"Use navigation background image",
        @"Use yellow navigation tint",
        @"Use large title style",
        @"Use light status bar style",
        @"Use thirty point navigation items",
        @"Remove navigation item margins",
        @"Use gradient navigation background",
        @"Use system navigation bar",
        @"Show secondary trailing action",
        @"Disable back navigation"
    ];
    NSUInteger count = MIN(self.settingRowLayouts.count, identifiers.count);
    for (NSUInteger index = 0; index < count; index++) {
        UISwitch *toggle = self.settingRowLayouts[index].toggle;
        toggle.accessibilityIdentifier = identifiers[index];
        toggle.accessibilityLabel = labels[index];
    }
    self.backgroundColorSwitch = self.settingRowLayouts.firstObject.toggle;
}

- (void)setUpGeometryProbe {
    UILabel *probe = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    probe.text = @" ";
    probe.textColor = UIColor.clearColor;
    probe.backgroundColor = UIColor.clearColor;
    probe.isAccessibilityElement = YES;
    probe.accessibilityIdentifier = @"demo.property.geometry";
    probe.accessibilityLabel = @"Property page geometry";
    probe.userInteractionEnabled = NO;
    [self.view addSubview:probe];
    self.geometryProbe = probe;
}

- (void)updateSettingRowsForReservedRegions {
    for (DemoSettingRowLayout *layout in self.settingRowLayouts) {
        UIView *row = layout.row;
        if (!row || CGRectIsEmpty(row.bounds)) {
            continue;
        }
        NSArray<NSValue *> *segments = ZXNavigationBarAvailableHorizontalSegments(
            row.bounds,
            ZXNavigationBarSafeAreaInsetsForView(row),
            ZXNavigationBarActiveReservedRegionFramesForView(row)
        );
        CGRect segment = ZXNavigationBarLargestHorizontalSegment(segments);
        CGFloat leading = layout.defaultLeading;
        CGFloat trailing = layout.defaultTrailing;
        if (!CGRectIsEmpty(segment)) {
            leading += MAX(0, CGRectGetMinX(segment) - CGRectGetMinX(row.bounds));
            trailing += MAX(0, CGRectGetMaxX(row.bounds) - CGRectGetMaxX(segment));
        }
        if (fabs(layout.leadingConstraint.constant - leading) > 0.5 ||
            fabs(layout.trailingConstraint.constant - trailing) > 0.5) {
            layout.leadingConstraint.constant = leading;
            layout.trailingConstraint.constant = trailing;
            [row layoutIfNeeded];
        }
    }
}

- (void)updateGeometryProbe {
    UIWindow *window = self.view.window;
    if (!window || !self.geometryProbe) {
        return;
    }
    self.geometryProbe.frame = CGRectMake(0, MAX(0, CGRectGetHeight(self.view.bounds) - 1), 1, 1);
    CGRect navFrame = [self.zx_navBar.superview convertRect:self.zx_navBar.frame toView:window];
    CGRect switchFrame = [self.backgroundColorSwitch.superview convertRect:self.backgroundColorSwitch.frame toView:window];
    DemoSettingRowLayout *firstRowLayout = self.settingRowLayouts.firstObject;
    DemoSettingRowLayout *secondRowLayout = self.settingRowLayouts.count > 1 ? self.settingRowLayouts[1] : nil;
    CGRect labelFrame = [firstRowLayout.label.superview convertRect:firstRowLayout.label.frame toView:window];
    CGRect rowFrame = [firstRowLayout.row.superview convertRect:firstRowLayout.row.frame toView:window];
    CGRect secondLabelFrame = [secondRowLayout.label.superview convertRect:secondRowLayout.label.frame toView:window];
    CGRect secondToggleFrame = [secondRowLayout.toggle.superview convertRect:secondRowLayout.toggle.frame toView:window];
    CGRect secondRowFrame = [secondRowLayout.row.superview convertRect:secondRowLayout.row.frame toView:window];
    CGRect scrollFrame = [self.settingsScrollView.superview convertRect:self.settingsScrollView.frame toView:window];
    BOOL navBackgroundOrange = self.zx_navBar.backgroundColor &&
        CGColorEqualToColor(self.zx_navBar.backgroundColor.CGColor, UIColor.orangeColor.CGColor);
    NSMutableString *value = [NSMutableString stringWithFormat:
        @"nav={%.1f,%.1f,%.1f,%.1f};navContent=%.1f;scroll={%.1f,%.1f,%.1f,%.1f};scrollContentHeight=%.1f;firstRow={%.1f,%.1f,%.1f,%.1f};firstLabel={%.1f,%.1f,%.1f,%.1f};toggle={%.1f,%.1f,%.1f,%.1f};secondRow={%.1f,%.1f,%.1f,%.1f};secondLabel={%.1f,%.1f,%.1f,%.1f};secondToggle={%.1f,%.1f,%.1f,%.1f};secondLeading=%.1f;secondTrailing=%.1f;backgroundOn=%d;navBackgroundOrange=%d",
        CGRectGetMinX(navFrame), CGRectGetMinY(navFrame), CGRectGetWidth(navFrame), CGRectGetHeight(navFrame),
        CGRectGetHeight(self.zx_navBar.bounds) - ZXNavigationBarStatusBarHeightForView(self.zx_navBar),
        CGRectGetMinX(scrollFrame), CGRectGetMinY(scrollFrame), CGRectGetWidth(scrollFrame), CGRectGetHeight(scrollFrame),
        self.settingsScrollView.contentSize.height,
        CGRectGetMinX(rowFrame), CGRectGetMinY(rowFrame), CGRectGetWidth(rowFrame), CGRectGetHeight(rowFrame),
        CGRectGetMinX(labelFrame), CGRectGetMinY(labelFrame), CGRectGetWidth(labelFrame), CGRectGetHeight(labelFrame),
        CGRectGetMinX(switchFrame), CGRectGetMinY(switchFrame), CGRectGetWidth(switchFrame), CGRectGetHeight(switchFrame),
        CGRectGetMinX(secondRowFrame), CGRectGetMinY(secondRowFrame), CGRectGetWidth(secondRowFrame), CGRectGetHeight(secondRowFrame),
        CGRectGetMinX(secondLabelFrame), CGRectGetMinY(secondLabelFrame), CGRectGetWidth(secondLabelFrame), CGRectGetHeight(secondLabelFrame),
        CGRectGetMinX(secondToggleFrame), CGRectGetMinY(secondToggleFrame), CGRectGetWidth(secondToggleFrame), CGRectGetHeight(secondToggleFrame),
        secondRowLayout.leadingConstraint.constant, secondRowLayout.trailingConstraint.constant,
        self.backgroundColorSwitch.isOn, navBackgroundOrange];
    NSArray<NSValue *> *reservedFrames = ZXNavigationBarActiveReservedRegionFramesForView(self.view);
    [value appendFormat:@";reservedCount=%lu", (unsigned long)reservedFrames.count];
    [reservedFrames enumerateObjectsUsingBlock:^(NSValue *frameValue, NSUInteger index, BOOL *stop) {
        CGRect frame = [self.view convertRect:frameValue.CGRectValue toView:window];
        [value appendFormat:@";reserved%lu={%.1f,%.1f,%.1f,%.1f}", (unsigned long)index,
            CGRectGetMinX(frame), CGRectGetMinY(frame), CGRectGetWidth(frame), CGRectGetHeight(frame)];
    }];
    self.geometryProbe.accessibilityValue = value;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView != self.settingsScrollView) {
        return;
    }
    [self updateSettingRowsForReservedRegions];
    [self updateGeometryProbe];
}

#pragma mark - Actions

#pragma mark 点击了设置背景色橙色
- (IBAction)changeBacColorAction:(UISwitch *)sender {
    if(sender.on){
        self.zx_navBarBackgroundColor = [UIColor orangeColor];
    }else{
        self.zx_navBarBackgroundColor = [UIColor whiteColor];
    }
    [self updateGeometryProbe];
}

#pragma mark 点击了设置背景图片
- (IBAction)setBacImageAction:(UISwitch *)sender {
    if(sender.on){
        self.zx_navBarBackgroundImage = [UIImage imageNamed:@"nav_bac"];
    }else{
        self.zx_navBarBackgroundImage = nil;
    }
}

#pragma mark 点击了设置TintColor黄色
- (IBAction)ChangeTintColorAction:(UISwitch *)sender {
    if(sender.on){
        self.zx_navTintColor = [UIColor yellowColor];
    }else{
        self.zx_navTintColor = [UIColor blackColor];
    }
}

#pragma mark 点击了设置大小标题效果
- (IBAction)setBigSubTitleAction:(UISwitch *)sender {
    if(sender.on){
        [self zx_setMultiTitle:@"ZXNavigationBar" subTitle:@"subTitle"];
    }else{
        self.title = @"ZXNavigationBar";
    }
}

#pragma mark 点击了设置StatusBar白色
- (IBAction)changeStatusBarAction:(UISwitch *)sender {
    if(sender.on){
        self.zx_navStatusBarStyle = ZXNavStatusBarStyleLight;
    }else{
        self.zx_navStatusBarStyle = ZXNavStatusBarStyleDefault;
    }
}

#pragma mark 点击了设置两边Item大小为30
- (IBAction)changeItemSizeAction:(UISwitch *)sender {
    if(sender.on){
        self.zx_navItemSize = 30;
    }else{
        self.zx_navItemSize = ZXNavDefalutItemSize;
    }
}

#pragma mark 点击了设置两边Item边距为0
- (IBAction)changeItemMarginAction:(UISwitch *)sender {
    if(sender.on){
        self.zx_navItemMargin = 0;
    }else{
        self.zx_navItemMargin = ZXNavDefalutItemMargin;
    }
}

#pragma mark 点击了设置渐变背景
- (IBAction)changeGradientBacAction:(UISwitch *)sender {
    if(sender.on){
        [self zx_setNavGradientBacFrom:[UIColor magentaColor] to:[UIColor cyanColor]];
    }else{
        [self zx_removeNavGradientBac];
    }
    
}

#pragma mark 点击了更换为系统的导航栏
- (IBAction)changeSystemNavBarAction:(UISwitch *)sender {
    if(sender.on){
        self.zx_showSystemNavBar = YES;
    }else{
        self.zx_showSystemNavBar = NO;
        self.zx_hideBaseNavBar = NO;
    }
    
}

#pragma mark 点击了右侧显示两个Item
- (IBAction)changeRightSubBtnAction:(UISwitch *)sender {
    if(sender.on){
        //设置自定义NavItemView
        self.zx_navSubRightBtn.zx_customView = [UISwitch new];
    }else{
        self.zx_navSubRightBtn.zx_customView = nil;
    }
}

- (IBAction)disPopAction:(UISwitch *)sender {
    self.disablePop = sender.on;
}

@end
