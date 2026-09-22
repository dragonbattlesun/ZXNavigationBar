//
//  DemoAdaptiveLayoutViewController.m
//  ZXNavigationBarDemo
//

#import "DemoAdaptiveLayoutViewController.h"
#import "ZXNavigationBarController.h"
#import "ZXNavigationBarNavigationController.h"
#import "ZXNavigationBarTableViewController.h"
#import "ZXNavigationBarGeometry.h"

// 在基类初始化前建立与 XIB 相同的 safe-area 顶部约束。
@interface DemoAdaptiveContentController : ZXNavigationBarController
@property (strong, nonatomic) NSLayoutConstraint *contentTopConstraint;
@end
@implementation DemoAdaptiveContentController
- (void)viewDidLoad {
    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:content];
    self.contentTopConstraint = [content.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12];
    [NSLayoutConstraint activateConstraints:@[self.contentTopConstraint,
        [content.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [content.widthAnchor constraintEqualToConstant:1], [content.heightAnchor constraintEqualToConstant:1]]];
    [super viewDidLoad];
}
@end

@interface DemoAdaptiveTableController : ZXNavigationBarTableViewController
@end
@implementation DemoAdaptiveTableController
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 100; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"fixture.row"];
    if (!cell) { cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"fixture.row"]; }
    cell.textLabel.text = [NSString stringWithFormat:@"Row %ld", (long)indexPath.row];
    return cell;
}
@end

@interface DemoAdaptiveLayoutViewController ()

@property (strong, nonatomic) ZXNavigationBarNavigationController *fixtureNavigationController;
@property (strong, nonatomic) ZXNavigationBarController *currentViewController;
@property (weak, nonatomic) ZXNavigationBar *configuredNavigationBar;
@property (strong, nonatomic) NSLayoutConstraint *containerLeadingConstraint;
@property (strong, nonatomic) NSLayoutConstraint *containerWidthConstraint;
@property (strong, nonatomic) UILabel *verticalBehaviorLabel;
@property (strong, nonatomic) UILabel *stateLabel;
@property (assign, nonatomic) NSInteger revision;
@property (assign, nonatomic) BOOL usesCompactContainer;
@property (assign, nonatomic) BOOL tableModeRequested;
@property (assign, nonatomic) CGFloat leadingInset;
@property (assign, nonatomic) CGFloat trailingInset;
@property (strong, nonatomic) NSLayoutConstraint *containerHeightConstraint;
@property (assign, nonatomic) BOOL foldOnNextRotation;
@property (assign, nonatomic) BOOL rotating;
@property (assign, nonatomic) NSInteger foldCompletions;
@property (assign, nonatomic) NSInteger foldingRotationSamples;
@property (assign, nonatomic) CGFloat foldingWidthError;

@end

@implementation DemoAdaptiveLayoutViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];
    self.revision = 1;
    [self setUpNavigationFixture];
    [self setUpControls];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateFixtureState];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    self.containerWidthConstraint.constant = CGRectGetWidth(self.view.bounds) * 0.8 - (self.usesCompactContainer ? 60 : 0);
    self.containerHeightConstraint.constant = CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds) ? 100 : 210;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    self.rotating = YES;
    if (self.foldOnNextRotation) {
        self.foldOnNextRotation = NO;
        __weak typeof(self) weakSelf = self;
        [self.currentViewController zx_setNavFolded:YES speed:1 foldingOffsetBlock:^(CGFloat offset) {
            // 首个真实折叠 tick 中叠加 resize，保证转场期间也覆盖已开始的折叠动画。
            if (weakSelf.foldingRotationSamples == 0 && weakSelf.rotating) {
                weakSelf.usesCompactContainer = YES;
                [weakSelf.view setNeedsLayout];
                [weakSelf.view layoutIfNeeded];
            }
            [weakSelf.currentViewController.view layoutIfNeeded];
            if (weakSelf.rotating) {
                weakSelf.foldingRotationSamples += 1;
                weakSelf.foldingWidthError = MAX(weakSelf.foldingWidthError, fabs(CGRectGetWidth(weakSelf.currentViewController.zx_navBar.frame) - CGRectGetWidth(weakSelf.currentViewController.view.bounds)));
            }
        } foldCompletionBlock:^{
            weakSelf.foldCompletions += 1;
            [weakSelf updateLayoutAfterFixtureAction];
        }];
    }
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        self.rotating = NO;
        [self updateLayoutAfterFixtureAction];
    }];
}

- (void)setUpNavigationFixture {
    ZXNavigationBarController *previousViewController = [[ZXNavigationBarController alloc] init];
    previousViewController.zx_navTitle = @"Previous";
    previousViewController.zx_showNavHistoryStackContentView = YES;

    ZXNavigationBarController *currentViewController = [[DemoAdaptiveContentController alloc] init];
    currentViewController.zx_navTitle = @"Fixture Navigation";
    currentViewController.zx_showNavHistoryStackContentView = YES;
    self.currentViewController = currentViewController;

    ZXNavigationBarNavigationController *navigationController = [[ZXNavigationBarNavigationController alloc] initWithRootViewController:previousViewController];
    [navigationController setViewControllers:@[previousViewController, currentViewController] animated:NO];
    self.fixtureNavigationController = navigationController;

    [self addChildViewController:navigationController];
    UIView *navigationView = navigationController.view;
    navigationView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:navigationView];
    [navigationController didMoveToParentViewController:self];

    self.containerLeadingConstraint = [navigationView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24.0];
    self.containerWidthConstraint = [navigationView.widthAnchor constraintEqualToConstant:320.0];
    self.containerHeightConstraint = [navigationView.heightAnchor constraintEqualToConstant:210.0];
    [NSLayoutConstraint activateConstraints:@[
        self.containerLeadingConstraint,
        self.containerWidthConstraint,
        [navigationView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8.0],
        self.containerHeightConstraint
    ]];

    [currentViewController view];
    [self configureNavigationAccessibility];
}

- (void)setUpControls {
    UIStackView *firstRow = [self rowWithViews:@[
        [self buttonWithTitle:@"Resize" identifier:@"fixture.resize" accessibilityLabel:@"Resize container" action:@selector(toggleContainerSize:)],
        [self buttonWithTitle:@"Leading" identifier:@"fixture.leadingInset" accessibilityLabel:@"Add leading safe area" action:@selector(toggleLeadingInset:)],
        [self buttonWithTitle:@"Trailing" identifier:@"fixture.trailingInset" accessibilityLabel:@"Add trailing safe area" action:@selector(toggleTrailingInset:)]
    ]];
    UIStackView *secondRow = [self rowWithViews:@[
        [self buttonWithTitle:@"Fold" identifier:@"fixture.fold" accessibilityLabel:@"Toggle navigation fold" action:@selector(toggleFold:)],
        [self buttonWithTitle:@"History" identifier:@"fixture.history" accessibilityLabel:@"Show navigation history" action:@selector(showHistory:)],
        [self buttonWithTitle:@"System bar" identifier:@"fixture.systemBar" accessibilityLabel:@"Toggle system navigation bar" action:@selector(toggleSystemBar:)]
    ]];
    UIStackView *thirdRow = [self rowWithViews:@[
        [self buttonWithTitle:@"Table mode" identifier:@"fixture.tableMode" accessibilityLabel:@"Toggle table mode" action:@selector(toggleTableMode:)],
        [self buttonWithTitle:@"Scroll" identifier:@"fixture.scroll" accessibilityLabel:@"Scroll table" action:@selector(scrollTable:)],
        [self buttonWithTitle:@"Fold rotation" identifier:@"fixture.foldRotation" accessibilityLabel:@"Fold during next rotation" action:@selector(armFoldRotation:)]
    ]];

    self.verticalBehaviorLabel = [[UILabel alloc] init];
    self.verticalBehaviorLabel.text = @"Vertical bar behavior unavailable";
    self.verticalBehaviorLabel.textAlignment = NSTextAlignmentCenter;
    self.verticalBehaviorLabel.accessibilityIdentifier = @"fixture.verticalBehavior";
    self.verticalBehaviorLabel.accessibilityLabel = @"Vertical bar behavior";
    self.verticalBehaviorLabel.accessibilityValue = @"unavailable";

    self.stateLabel = [[UILabel alloc] init];
    self.stateLabel.font = [UIFont systemFontOfSize:11.0];
    self.stateLabel.numberOfLines = 0;
    self.stateLabel.textAlignment = NSTextAlignmentCenter;
    self.stateLabel.accessibilityIdentifier = @"fixture.state";
    self.stateLabel.accessibilityLabel = @"Fixture state";

    UIStackView *controls = [[UIStackView alloc] initWithArrangedSubviews:@[firstRow, secondRow, thirdRow, self.verticalBehaviorLabel, self.stateLabel]];
    controls.axis = UILayoutConstraintAxisVertical;
    controls.spacing = 8.0;
    controls.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:controls];
    [NSLayoutConstraint activateConstraints:@[
        [controls.leadingAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.leadingAnchor],
        [controls.trailingAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.trailingAnchor],
        [controls.topAnchor constraintEqualToAnchor:self.fixtureNavigationController.view.bottomAnchor constant:16.0]
    ]];
}

- (UIStackView *)rowWithViews:(NSArray<UIView *> *)views {
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:views];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.distribution = UIStackViewDistributionFillEqually;
    row.spacing = 8.0;
    return row;
}

- (UIButton *)buttonWithTitle:(NSString *)title
                    identifier:(NSString *)identifier
            accessibilityLabel:(NSString *)accessibilityLabel
                        action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.accessibilityIdentifier = identifier;
    button.accessibilityLabel = accessibilityLabel;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)configureNavigationAccessibility {
    ZXNavigationBarController *viewController = self.currentViewController;
    if (!viewController.zx_navBar || self.configuredNavigationBar == viewController.zx_navBar) {
        return;
    }
    self.configuredNavigationBar = viewController.zx_navBar;

    viewController.zx_navLeftBtn.accessibilityIdentifier = @"fixture.nav.left";
    viewController.zx_navLeftBtn.accessibilityLabel = @"Back";
    viewController.zx_navSubLeftBtn.accessibilityIdentifier = @"fixture.nav.subLeft";
    viewController.zx_navSubLeftBtn.accessibilityLabel = @"Secondary back action";
    viewController.zx_navTitleLabel.accessibilityIdentifier = @"fixture.nav.title";
    viewController.zx_navTitleLabel.accessibilityLabel = @"Fixture navigation title";
    viewController.zx_navSubRightBtn.accessibilityIdentifier = @"fixture.nav.subRight";
    viewController.zx_navSubRightBtn.accessibilityLabel = @"Secondary action";
    viewController.zx_navRightBtn.accessibilityIdentifier = @"fixture.nav.right";
    viewController.zx_navRightBtn.accessibilityLabel = @"Primary action";

    [viewController.zx_navSubLeftBtn setTitle:@"Sub left" forState:UIControlStateNormal];
    [viewController.zx_navSubRightBtn setTitle:@"Sub right" forState:UIControlStateNormal];
    [viewController.zx_navRightBtn setTitle:@"Action" forState:UIControlStateNormal];
}

- (void)toggleContainerSize:(UIButton *)sender {
    self.usesCompactContainer = !self.usesCompactContainer;
    self.containerLeadingConstraint.constant = self.usesCompactContainer ? 56.0 : 24.0;
    self.containerWidthConstraint.constant = self.usesCompactContainer ? 260.0 : 320.0;
    [self updateLayoutAfterFixtureAction];
}

- (void)toggleLeadingInset:(UIButton *)sender {
    self.leadingInset = self.leadingInset > 0.0 ? 0.0 : 28.0;
    [self applyAdditionalSafeAreaInsets];
    [self updateLayoutAfterFixtureAction];
}

- (void)toggleTrailingInset:(UIButton *)sender {
    self.trailingInset = self.trailingInset > 0.0 ? 0.0 : 36.0;
    [self applyAdditionalSafeAreaInsets];
    [self updateLayoutAfterFixtureAction];
}

- (void)toggleFold:(UIButton *)sender {
    BOOL folded = !self.currentViewController.zx_navIsFolded;
    __weak typeof(self) weakSelf = self;
    [self.currentViewController zx_setNavFolded:folded speed:3 foldingOffsetBlock:nil foldCompletionBlock:^{
        [weakSelf updateFixtureState];
    }];
    [self updateLayoutAfterFixtureAction];
}

- (void)showHistory:(UIButton *)sender {
    [self.currentViewController zx_showNavHistoryStackView];
    [self updateLayoutAfterFixtureAction];
}

- (void)toggleSystemBar:(UIButton *)sender {
    self.currentViewController.zx_showSystemNavBar = !self.currentViewController.zx_showSystemNavBar;
    [self updateLayoutAfterFixtureAction];
}

- (void)toggleTableMode:(UIButton *)sender {
    if (self.tableModeRequested) { return; }
    self.tableModeRequested = YES;
    DemoAdaptiveTableController *tableController = [[DemoAdaptiveTableController alloc] initWithStyle:UITableViewStylePlain];
    tableController.zx_navTitle = @"Fixture Navigation";
    [self.fixtureNavigationController pushViewController:tableController animated:NO];
    // 两个库基类提供相同的导航栏公开接口；这里只复用 fixture 的观测路径。
    self.currentViewController = (ZXNavigationBarController *)(id)tableController;
    [tableController view];
    [self configureNavigationAccessibility];
    sender.accessibilityValue = self.tableModeRequested ? @"on" : @"off";
    [self updateLayoutAfterFixtureAction];
}

- (void)scrollTable:(UIButton *)sender {
    if (self.tableModeRequested) {
        [(DemoAdaptiveTableController *)(id)self.currentViewController tableView].contentOffset = CGPointMake(0, 440);
    }
    [self updateLayoutAfterFixtureAction];
}

- (void)armFoldRotation:(UIButton *)sender {
    self.foldOnNextRotation = YES;
    [self updateLayoutAfterFixtureAction];
}

- (void)applyAdditionalSafeAreaInsets {
    self.currentViewController.additionalSafeAreaInsets = UIEdgeInsetsMake(0.0, self.leadingInset, 0.0, self.trailingInset);
}

- (void)updateLayoutAfterFixtureAction {
    self.revision += 1;
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    [self updateFixtureState];
}

- (void)updateFixtureState {
    [self.currentViewController.view layoutIfNeeded];
    [self.currentViewController.zx_navBar layoutIfNeeded];
    CGRect containerFrame = [self.fixtureNavigationController.view.superview convertRect:self.fixtureNavigationController.view.frame toView:self.view];
    CGRect navigationFrame = [self.currentViewController.view convertRect:self.currentViewController.zx_navBar.frame toView:self.view];
    UILabel *titleLabel = self.currentViewController.zx_navTitleLabel;
    CGRect titleFrame = [titleLabel.superview convertRect:titleLabel.frame toView:self.view];
    UIEdgeInsets safeAreaInsets = self.currentViewController.view.safeAreaInsets;
    NSString *mode = self.currentViewController.zx_showSystemNavBar ? @"system" : @"custom";
    self.stateLabel.text = [NSString stringWithFormat:@"revision=%ld;container={%.1f,%.1f,%.1f,%.1f};nav={%.1f,%.1f,%.1f,%.1f};safe={%.1f,%.1f,%.1f,%.1f};mode=%@;folded=%d;table=%d;title={%.1f,%.1f,%.1f,%.1f};titleIdentifier=%@;titleLabel=%@",
                            (long)self.revision,
                            CGRectGetMinX(containerFrame), CGRectGetMinY(containerFrame), CGRectGetWidth(containerFrame), CGRectGetHeight(containerFrame),
                            CGRectGetMinX(navigationFrame), CGRectGetMinY(navigationFrame), CGRectGetWidth(navigationFrame), CGRectGetHeight(navigationFrame),
                            safeAreaInsets.top, safeAreaInsets.left, safeAreaInsets.bottom, safeAreaInsets.right,
                            mode,
                            self.currentViewController.zx_navIsFolded,
                            self.tableModeRequested,
                            CGRectGetMinX(titleFrame), CGRectGetMinY(titleFrame), CGRectGetWidth(titleFrame), CGRectGetHeight(titleFrame),
                            titleLabel.accessibilityIdentifier, titleLabel.accessibilityLabel];
    self.stateLabel.accessibilityValue = self.stateLabel.text;
    CGFloat topConstraint = [self.currentViewController isKindOfClass:DemoAdaptiveContentController.class] ? ((DemoAdaptiveContentController *)self.currentViewController).contentTopConstraint.constant : 0;
    UITableView *table = self.tableModeRequested ? [(DemoAdaptiveTableController *)(id)self.currentViewController tableView] : nil;
    NSString *details = [NSString stringWithFormat:@";status=%.1f;contentTop=%.1f;offset=%.1f;inset=%.1f;foldCompletions=%ld;foldSamples=%ld;foldWidthError=%.1f;landscape=%d;stack=%lu",
        ZXNavigationBarStatusBarHeightForView(self.currentViewController.view), topConstraint, table.contentOffset.y, table.contentInset.top,
        (long)self.foldCompletions, (long)self.foldingRotationSamples, self.foldingWidthError,
        CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds), (unsigned long)self.fixtureNavigationController.viewControllers.count];
    self.stateLabel.accessibilityValue = [self.stateLabel.text stringByAppendingString:details];
}

@end
