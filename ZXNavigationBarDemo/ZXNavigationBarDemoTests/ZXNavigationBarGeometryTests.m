#import <XCTest/XCTest.h>
#import "ZXNavigationBar.h"
#import "ZXNavigationBarGeometry.h"

FOUNDATION_EXPORT NSArray<NSValue *> *ZXNavigationBarGeometryFilterActiveReservedRegionFrames(NSArray *regions);

@interface ZXNavigationBarReservedRegionDouble : NSObject

@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, assign) CGRect frame;

@end

@implementation ZXNavigationBarReservedRegionDouble
@end

@interface ZXNavigationBarLocalSafeAreaView : UIView

@property (nonatomic, assign) UIEdgeInsets stubbedSafeAreaInsets;

@end

@implementation ZXNavigationBarLocalSafeAreaView

- (UIEdgeInsets)safeAreaInsets {
    return self.stubbedSafeAreaInsets;
}

@end

@interface ZXNavigationBarGeometryTests : XCTestCase
@end

@implementation ZXNavigationBarGeometryTests

- (UIWindow *)keyWindowForHostedApplication {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) {
                return window;
            }
        }
    }
    return nil;
}

- (void)testSmoothBackgroundUsesOwningWindowOnly {
    UIWindow *hostWindow = [self keyWindowForHostedApplication];
    XCTAssertNotNil(hostWindow);
    if (!hostWindow) {
        return;
    }

    UIColor *originalHostColor = hostWindow.backgroundColor;
    UIColor *hostSentinelColor = UIColor.redColor;
    UIColor *owningSentinelColor = UIColor.blueColor;
    UIColor *targetColor = UIColor.greenColor;
    hostWindow.backgroundColor = hostSentinelColor;

    UIWindow *owningWindow = [[UIWindow alloc] initWithWindowScene:hostWindow.windowScene];
    owningWindow.frame = CGRectMake(0, 0, 320, 100);
    owningWindow.backgroundColor = owningSentinelColor;
    ZXNavigationBar *navigationBar = [[ZXNavigationBar alloc] initWithFrame:owningWindow.bounds];
    [owningWindow addSubview:navigationBar];
    XCTAssertEqual(navigationBar.window, owningWindow);

    [navigationBar setValue:@YES forKey:@"zx_navEnableSmoothFromSystemNavBar"];
    navigationBar.backgroundColor = targetColor;

    XCTAssertEqualObjects(owningWindow.backgroundColor, targetColor);
    XCTAssertEqualObjects(hostWindow.backgroundColor, hostSentinelColor);

    ZXNavigationBar *unattachedNavigationBar = [[ZXNavigationBar alloc] initWithFrame:CGRectMake(0, 0, 320, 100)];
    [unattachedNavigationBar setValue:@YES forKey:@"zx_navEnableSmoothFromSystemNavBar"];
    XCTAssertNoThrow(unattachedNavigationBar.backgroundColor = UIColor.orangeColor);
    XCTAssertEqualObjects(hostWindow.backgroundColor, hostSentinelColor);

    hostWindow.backgroundColor = originalHostColor;
}

- (void)testSafeAreaWithoutReservedRegionReturnsSingleSegment {
    CGRect content = CGRectMake(0, 20, 800, 44);
    UIEdgeInsets safe = UIEdgeInsetsMake(0, 24, 0, 40);

    NSArray<NSValue *> *segments = ZXNavigationBarAvailableHorizontalSegments(content, safe, @[]);

    XCTAssertEqual(segments.count, 1U);
    [self assertRect:segments.firstObject.CGRectValue equals:CGRectMake(24, 20, 736, 44)];
}

- (void)testSafeAreaInsetsFallsBackToZeroWithoutSafeAreaCapability {
    UIView *viewWithoutSafeAreaCapability = (UIView *)[NSObject new];
    UIEdgeInsets insets = UIEdgeInsetsZero;

    XCTAssertNoThrow(insets = ZXNavigationBarSafeAreaInsetsForView(viewWithoutSafeAreaCapability));
    XCTAssertEqualWithAccuracy(insets.top, 0, 0.5);
    XCTAssertEqualWithAccuracy(insets.left, 0, 0.5);
    XCTAssertEqualWithAccuracy(insets.bottom, 0, 0.5);
    XCTAssertEqualWithAccuracy(insets.right, 0, 0.5);
}

- (void)testStatusHeightUsesAttachedViewsLocalSafeAreaInsteadOfSceneStatusBar {
    UIWindow *hostWindow = [self keyWindowForHostedApplication];
    XCTAssertNotNil(hostWindow);
    if (!hostWindow) {
        return;
    }

    ZXNavigationBarLocalSafeAreaView *nestedView = [[ZXNavigationBarLocalSafeAreaView alloc] initWithFrame:CGRectMake(0, 100, 200, 100)];
    nestedView.stubbedSafeAreaInsets = UIEdgeInsetsMake(7, 0, 0, 0);
    [hostWindow addSubview:nestedView];

    XCTAssertEqualWithAccuracy(ZXNavigationBarStatusBarHeightForView(nestedView), 7, 0.5);
    [nestedView removeFromSuperview];
}

- (void)testStatusHeightDoesNotLeakSceneStatusIntoNestedSafeArea {
    UIWindow *hostWindow = [self keyWindowForHostedApplication];
    XCTAssertNotNil(hostWindow);
    if (!hostWindow) {
        return;
    }

    ZXNavigationBarLocalSafeAreaView *nestedView = [[ZXNavigationBarLocalSafeAreaView alloc] initWithFrame:CGRectMake(0, 100, 200, 100)];
    nestedView.stubbedSafeAreaInsets = UIEdgeInsetsZero;
    [hostWindow addSubview:nestedView];

    XCTAssertEqualWithAccuracy(ZXNavigationBarStatusBarHeightForView(nestedView), 0, 0.5);
    [nestedView removeFromSuperview];
}

- (void)testStatusHeightForUnattachedViewIsDeterministicZero {
    ZXNavigationBarLocalSafeAreaView *unattachedView = [ZXNavigationBarLocalSafeAreaView new];
    unattachedView.stubbedSafeAreaInsets = UIEdgeInsetsZero;

    XCTAssertNil(unattachedView.window);
    XCTAssertEqualWithAccuracy(ZXNavigationBarStatusBarHeightForView(unattachedView), 0, 0.5);
}

- (void)testMiddleDivisionSplitsContentIntoTwoSegments {
    CGRect content = CGRectMake(0, 20, 800, 44);
    UIEdgeInsets safe = UIEdgeInsetsMake(0, 24, 0, 40);
    NSArray *regions = @[
        [NSValue valueWithCGRect:CGRectMake(390, 0, 20, 100)]
    ];

    NSArray<NSValue *> *segments = ZXNavigationBarAvailableHorizontalSegments(content, safe, regions);

    XCTAssertEqual(segments.count, 2U);
    if (segments.count != 2U) {
        return;
    }
    [self assertRect:segments[0].CGRectValue equals:CGRectMake(24, 20, 366, 44)];
    [self assertRect:segments[1].CGRectValue equals:CGRectMake(410, 20, 350, 44)];
}

- (void)testOverlappingRegionsAreMergedBeforeSubtraction {
    CGRect content = CGRectMake(0, 20, 800, 44);
    NSArray *regions = @[
        [NSValue valueWithCGRect:CGRectMake(100, 0, 120, 100)],
        [NSValue valueWithCGRect:CGRectMake(180, 0, 100, 100)]
    ];

    NSArray<NSValue *> *segments = ZXNavigationBarAvailableHorizontalSegments(content, UIEdgeInsetsZero, regions);

    XCTAssertEqual(segments.count, 2U);
    if (segments.count != 2U) {
        return;
    }
    [self assertRect:segments[0].CGRectValue equals:CGRectMake(0, 20, 100, 44)];
    [self assertRect:segments[1].CGRectValue equals:CGRectMake(280, 20, 520, 44)];
}

- (void)testOuterOcclusionAndSafeAreaUseTheStricterBoundary {
    CGRect content = CGRectMake(0, 20, 800, 44);
    UIEdgeInsets safe = UIEdgeInsetsMake(0, 24, 0, 40);
    NSArray *regions = @[
        [NSValue valueWithCGRect:CGRectMake(-20, 0, 60, 100)],
        [NSValue valueWithCGRect:CGRectMake(750, 0, 100, 100)]
    ];

    NSArray<NSValue *> *segments = ZXNavigationBarAvailableHorizontalSegments(content, safe, regions);

    XCTAssertEqual(segments.count, 1U);
    [self assertRect:segments.firstObject.CGRectValue equals:CGRectMake(40, 20, 710, 44)];
}

- (void)testRegionOutsideContentRowIsIgnored {
    CGRect content = CGRectMake(0, 20, 800, 44);
    UIEdgeInsets safe = UIEdgeInsetsMake(0, 24, 0, 40);
    NSArray *regions = @[
        [NSValue valueWithCGRect:CGRectMake(390, 64, 20, 20)]
    ];

    NSArray<NSValue *> *segments = ZXNavigationBarAvailableHorizontalSegments(content, safe, regions);

    XCTAssertEqual(segments.count, 1U);
    [self assertRect:segments.firstObject.CGRectValue equals:CGRectMake(24, 20, 736, 44)];
}

- (void)testLargestSegmentBreaksTieTowardPhysicalLeft {
    NSArray<NSValue *> *segments = @[
        [NSValue valueWithCGRect:CGRectMake(0, 20, 45, 44)],
        [NSValue valueWithCGRect:CGRectMake(55, 20, 45, 44)]
    ];

    [self assertRect:ZXNavigationBarLargestHorizontalSegment(segments) equals:CGRectMake(0, 20, 45, 44)];
}

- (void)testFullyOccludedContentReturnsNoSegment {
    NSArray<NSValue *> *segments = ZXNavigationBarAvailableHorizontalSegments(
        CGRectMake(0, 20, 100, 44),
        UIEdgeInsetsZero,
        @[[NSValue valueWithCGRect:CGRectMake(-10, 0, 120, 100)]]
    );

    XCTAssertEqual(segments.count, 0U);
    [self assertRect:ZXNavigationBarLargestHorizontalSegment(segments) equals:CGRectZero];
}

- (void)testReservedRegionQueryDropsInactiveRegions {
    ZXNavigationBarReservedRegionDouble *activeRegion = [ZXNavigationBarReservedRegionDouble new];
    activeRegion.isActive = YES;
    activeRegion.frame = CGRectMake(390, 0, 20, 100);
    ZXNavigationBarReservedRegionDouble *inactiveRegion = [ZXNavigationBarReservedRegionDouble new];
    inactiveRegion.isActive = NO;
    inactiveRegion.frame = CGRectMake(410, 0, 20, 100);
    ZXNavigationBarReservedRegionDouble *emptyActiveRegion = [ZXNavigationBarReservedRegionDouble new];
    emptyActiveRegion.isActive = YES;
    emptyActiveRegion.frame = CGRectZero;

    NSArray<NSValue *> *frames = ZXNavigationBarGeometryFilterActiveReservedRegionFrames(@[
        activeRegion,
        inactiveRegion,
        emptyActiveRegion
    ]);

    XCTAssertEqual(frames.count, 1U);
    [self assertRect:frames.firstObject.CGRectValue equals:activeRegion.frame];
}

- (void)assertRect:(CGRect)actual equals:(CGRect)expected {
    XCTAssertEqualWithAccuracy(actual.origin.x, expected.origin.x, 0.5);
    XCTAssertEqualWithAccuracy(actual.origin.y, expected.origin.y, 0.5);
    XCTAssertEqualWithAccuracy(actual.size.width, expected.size.width, 0.5);
    XCTAssertEqualWithAccuracy(actual.size.height, expected.size.height, 0.5);
}

- (void)testPrimaryActionConsumesNarrowSegmentBeforeSecondaryAction {
    CGRect segment = CGRectMake(20, 20, 25, 44);
    CGRect primary = ZXNavigationBarConstrainHorizontalFrame(CGRectMake(20, 25, 40, 30), segment);
    [self assertRect:primary equals:CGRectMake(20, 25, 25, 30)];
    CGRect remaining = CGRectMake(CGRectGetMaxX(primary), 20, MAX(0, CGRectGetMaxX(segment) - CGRectGetMaxX(primary)), 44);
    CGRect secondary = ZXNavigationBarConstrainHorizontalFrame(CGRectMake(CGRectGetMaxX(primary) + 8, 25, 30, 30), remaining);
    [self assertRect:secondary equals:CGRectMake(45, 25, 0, 30)];
    [self assertRect:ZXNavigationBarConstrainHorizontalFrame(CGRectMake(5, 25, 40, 30), segment)
              equals:CGRectMake(20, 25, 25, 30)];
}

- (void)testPreferredFrameStaysInAnchorSegmentWhenDivisionWouldBeCrossed {
    NSArray<NSValue *> *segments = @[
        [NSValue valueWithCGRect:CGRectMake(0, 80, 180, 300)],
        [NSValue valueWithCGRect:CGRectMake(200, 80, 300, 300)]
    ];

    CGRect fitted = ZXNavigationBarFitHorizontalFrame(CGRectMake(40, 80, 250, 220), segments);

    [self assertRect:fitted equals:CGRectMake(0, 80, 180, 220)];
}

- (void)testPreferredFrameUsesNearestSegmentAndPreservesAvailableWidth {
    NSArray<NSValue *> *segments = @[
        [NSValue valueWithCGRect:CGRectMake(0, 80, 180, 300)],
        [NSValue valueWithCGRect:CGRectMake(200, 80, 300, 300)]
    ];

    CGRect fitted = ZXNavigationBarFitHorizontalFrame(CGRectMake(230, 80, 250, 220), segments);

    [self assertRect:fitted equals:CGRectMake(230, 80, 250, 220)];
}

- (void)testPreferredFrameCollapsesWhenNoHorizontalSegmentExists {
    CGRect fitted = ZXNavigationBarFitHorizontalFrame(CGRectMake(40, 80, 250, 220), @[]);

    [self assertRect:fitted equals:CGRectMake(40, 80, 0, 220)];
}

- (void)testHorizontalDivisionProducesVerticalSegmentsAboveAndBelowFold {
    CGRect content = CGRectMake(0, 0, 400, 600);
    NSArray<NSValue *> *regions = @[
        [NSValue valueWithCGRect:CGRectMake(0, 200, 400, 20)]
    ];

    NSArray<NSValue *> *segments = ZXNavigationBarAvailableVerticalSegments(
        content,
        UIEdgeInsetsMake(10, 0, 30, 0),
        regions
    );

    XCTAssertEqual(segments.count, 2U);
    [self assertRect:segments[0].CGRectValue equals:CGRectMake(0, 10, 400, 190)];
    [self assertRect:segments[1].CGRectValue equals:CGRectMake(0, 220, 400, 350)];
}

- (void)testVerticalFitKeepsHistoryVisibleAboveHorizontalDivision {
    NSArray<NSValue *> *segments = @[
        [NSValue valueWithCGRect:CGRectMake(0, 0, 400, 200)],
        [NSValue valueWithCGRect:CGRectMake(0, 220, 400, 380)]
    ];

    CGRect fitted = ZXNavigationBarFitVerticalFrame(CGRectMake(20, 50, 250, 220), segments);

    [self assertRect:fitted equals:CGRectMake(20, 0, 250, 200)];
}

- (void)testVerticalFitUsesNearestSegmentBelowHorizontalDivision {
    NSArray<NSValue *> *segments = @[
        [NSValue valueWithCGRect:CGRectMake(0, 0, 400, 200)],
        [NSValue valueWithCGRect:CGRectMake(0, 220, 400, 380)]
    ];

    CGRect fitted = ZXNavigationBarFitVerticalFrame(CGRectMake(20, 260, 250, 220), segments);

    [self assertRect:fitted equals:CGRectMake(20, 260, 250, 220)];
}

- (void)testTitleUsesLargestSegmentAfterBothButtonGroupsAreExcluded {
    NSArray *exclusions = @[
        [NSValue valueWithCGRect:CGRectMake(100, 0, 20, 100)],
        [NSValue valueWithCGRect:CGRectMake(0, 20, 40, 44)],
        [NSValue valueWithCGRect:CGRectMake(250, 20, 50, 44)]
    ];
    NSArray *segments = ZXNavigationBarAvailableHorizontalSegments(CGRectMake(0, 20, 300, 44), UIEdgeInsetsZero, exclusions);
    [self assertRect:ZXNavigationBarLargestHorizontalSegment(segments) equals:CGRectMake(120, 20, 130, 44)];
}

- (void)testTitleReturnsZeroWhenButtonsConsumeAllRemainingSegments {
    NSArray *exclusions = @[
        [NSValue valueWithCGRect:CGRectMake(40, 0, 20, 100)],
        [NSValue valueWithCGRect:CGRectMake(0, 20, 40, 44)],
        [NSValue valueWithCGRect:CGRectMake(60, 20, 40, 44)]
    ];
    NSArray *segments = ZXNavigationBarAvailableHorizontalSegments(CGRectMake(0, 20, 100, 44), UIEdgeInsetsZero, exclusions);
    [self assertRect:ZXNavigationBarLargestHorizontalSegment(segments) equals:CGRectZero];
}

- (void)testTitleKeepsSymmetricFrameForRegionOutsideContentRow {
    [self assertTitleUnchangedByRegion:CGRectMake(390, 64, 20, 30)];
}

- (void)testTitleKeepsSymmetricFrameForRegionOutsideSafeContent {
    // 已由 safe area 避让的外缘遮挡，不能再次切换标题布局策略。
    [self assertTitleUnchangedByRegion:CGRectMake(-20, 0, 44, 100)];
    [self assertTitleUnchangedByRegion:CGRectMake(760, 0, 80, 100)];
}

- (void)assertTitleUnchangedByRegion:(CGRect)region {
    CGRect content = CGRectMake(0, 20, 800, 44);
    UIEdgeInsets safe = UIEdgeInsetsMake(0, 24, 0, 40);
    NSArray *buttons = @[
        [NSValue valueWithCGRect:CGRectMake(40, 27, 40, 30)],
        [NSValue valueWithCGRect:CGRectMake(680, 27, 64, 30)]
    ];
    CGRect symmetric = CGRectMake(136, 20, 528, 44);
    CGRect withoutRegion = ZXNavigationBarTitleFrame(content, safe, @[], buttons, symmetric);
    CGRect withRegion = ZXNavigationBarTitleFrame(content, safe, @[[NSValue valueWithCGRect:region]], buttons, symmetric);
    [self assertRect:withoutRegion equals:symmetric];
    [self assertRect:withRegion equals:withoutRegion];
}

- (void)testTitleSelectsLargestRemainingFrameForEffectiveRegion {
    CGRect content = CGRectMake(0, 20, 300, 44);
    NSArray *regions = @[[NSValue valueWithCGRect:CGRectMake(100, 0, 20, 100)]];
    NSArray *buttons = @[
        [NSValue valueWithCGRect:CGRectMake(0, 27, 40, 30)],
        [NSValue valueWithCGRect:CGRectMake(250, 27, 50, 30)]
    ];
    CGRect title = ZXNavigationBarTitleFrame(content, UIEdgeInsetsZero, regions, buttons, CGRectMake(50, 20, 200, 44));
    [self assertRect:title equals:CGRectMake(120, 20, 130, 44)];
}

@end
