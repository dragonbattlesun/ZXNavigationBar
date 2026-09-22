//
//  DemoAdaptiveLayoutViewController.m
//  ZXNavigationBarDemo
//

#import "DemoAdaptiveLayoutViewController.h"
#import "ZXNavigationBarController.h"
#import "ZXNavigationBarNavigationController.h"

@interface DemoAdaptiveLayoutViewController ()

@property (strong, nonatomic) ZXNavigationBarNavigationController *fixtureNavigationController;
@property (strong, nonatomic) ZXNavigationBarController *currentViewController;
@property (strong, nonatomic) NSLayoutConstraint *containerLeadingConstraint;
@property (strong, nonatomic) NSLayoutConstraint *containerWidthConstraint;
@property (strong, nonatomic) UILabel *verticalBehaviorLabel;
@property (strong, nonatomic) UILabel *stateLabel;
@property (assign, nonatomic) NSInteger revision;
@property (assign, nonatomic) BOOL usesCompactContainer;
@property (assign, nonatomic) BOOL tableModeRequested;
@property (assign, nonatomic) CGFloat leadingInset;
@property (assign, nonatomic) CGFloat trailingInset;

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
    [self configureNavigationAccessibility];
    [self updateFixtureState];
}

- (void)setUpNavigationFixture {
    ZXNavigationBarController *previousViewController = [[ZXNavigationBarController alloc] init];
    previousViewController.zx_navTitle = @"Previous";
    previousViewController.zx_showNavHistoryStackContentView = YES;

    ZXNavigationBarController *currentViewController = [[ZXNavigationBarController alloc] init];
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
    [NSLayoutConstraint activateConstraints:@[
        self.containerLeadingConstraint,
        self.containerWidthConstraint,
        [navigationView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8.0],
        [navigationView.heightAnchor constraintEqualToConstant:210.0]
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
    if (!viewController.zx_navBar) {
        return;
    }

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
    self.tableModeRequested = !self.tableModeRequested;
    sender.accessibilityValue = self.tableModeRequested ? @"on" : @"off";
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
}

@end
