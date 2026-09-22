#import <XCTest/XCTest.h>
#import "ZXNavigationBarGeometry.h"

@interface ZXNavigationBarGeometryTests : XCTestCase
@end

@implementation ZXNavigationBarGeometryTests

- (void)testSafeAreaWithoutReservedRegionReturnsSingleSegment {
    CGRect content = CGRectMake(0, 20, 800, 44);
    UIEdgeInsets safe = UIEdgeInsetsMake(0, 24, 0, 40);

    NSArray<NSValue *> *segments = ZXNavigationBarAvailableHorizontalSegments(content, safe, @[]);

    XCTAssertEqual(segments.count, 1U);
    [self assertRect:segments.firstObject.CGRectValue equals:CGRectMake(24, 20, 736, 44)];
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

#if defined(__IPHONE_27_1) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_27_1
- (void)testReservedRegionQueryDropsInactiveRegions {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];

    NSArray<NSValue *> *frames = ZXNavigationBarActiveReservedRegionFramesForView(view);

    XCTAssertEqual(frames.count, 0U);
}
#endif

- (void)assertRect:(CGRect)actual equals:(CGRect)expected {
    XCTAssertEqualWithAccuracy(actual.origin.x, expected.origin.x, 0.5);
    XCTAssertEqualWithAccuracy(actual.origin.y, expected.origin.y, 0.5);
    XCTAssertEqualWithAccuracy(actual.size.width, expected.size.width, 0.5);
    XCTAssertEqualWithAccuracy(actual.size.height, expected.size.height, 0.5);
}

@end
