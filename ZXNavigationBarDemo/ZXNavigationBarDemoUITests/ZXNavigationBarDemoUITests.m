//
//  ZXNavigationBarDemoUITests.m
//  ZXNavigationBarDemoUITests
//
//  Created by 李兆祥 on 2020/3/7.
//  Copyright © 2020 ZXLee. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface ZXNavigationBarDemoUITests : XCTestCase

@end

@implementation ZXNavigationBarDemoUITests

- (void)setUp {
    self.continueAfterFailure = NO;
}

- (void)tearDown {
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationPortrait;
    [super tearDown];
}

- (XCUIApplication *)launchAdaptiveFixture {
    XCUIDevice.sharedDevice.orientation = UIDeviceOrientationPortrait;

    XCUIApplication *app = [[XCUIApplication alloc] init];
    app.launchArguments = @[@"ZXNavigationBarAdaptiveLayoutUITests"];
    [app launch];

    XCTAssertTrue([app.buttons[@"fixture.resize"] waitForExistenceWithTimeout:5]);
    return app;
}

- (void)testAdaptiveFixtureLaunchesWithoutChangingDefaultDemo {
    XCUIApplication *app = [self launchAdaptiveFixture];

    NSDictionary *state = [self fixtureState:app];
    [self assertNavigationElements:app insideContainer:[self fixtureRect:state[@"container"]] state:state];
    XCTAssertEqualObjects(app.buttons[@"fixture.nav.left"].label, @"Back");
}

- (void)testDefaultDemoLaunchesWithoutFixtureArguments {
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];
    XCTAssertTrue([app.tables.cells.staticTexts[@"ZXNavigationBar属性设置"] waitForExistenceWithTimeout:5]);
    XCTAssertFalse(app.buttons[@"fixture.resize"].exists);
}

- (void)assertVerticalBarPolicyTransitions:(XCUIApplication *)app {
    XCUIElement *behavior = app.staticTexts[@"fixture.verticalBehavior"];
    XCTAssertEqualObjects(behavior.value, @"disabled");
    [self tapFixtureControl:@"fixture.systemBar" app:app];
    XCTAssertEqualObjects(behavior.value, @"automatic");
    XCTAssertEqualObjects([self fixtureState:app][@"mode"], @"system");
    [self tapFixtureControl:@"fixture.systemBar" app:app];
    XCTAssertEqualObjects(behavior.value, @"disabled");
    XCTAssertEqualObjects([self fixtureState:app][@"mode"], @"custom");
    XCTAssertTrue(app.buttons[@"fixture.nav.left"].exists);
}

- (void)testVerticalBarPolicyMatchesVisibleNavigationMode {
    XCUIApplication *app = [self launchAdaptiveFixture];
    if (@available(iOS 27.1, *)) {
        [self assertVerticalBarPolicyTransitions:app];
    } else {
        XCTAssertEqualObjects(app.staticTexts[@"fixture.verticalBehavior"].value, @"unavailable");
    }
}

- (void)testTableVerticalBarPolicyMatchesVisibleNavigationMode {
    XCUIApplication *app = [self launchAdaptiveFixture];
    [self tapFixtureControl:@"fixture.tableMode" app:app];
    if (@available(iOS 27.1, *)) {
        [self assertVerticalBarPolicyTransitions:app];
    } else {
        XCTAssertEqualObjects(app.staticTexts[@"fixture.verticalBehavior"].value, @"unavailable");
    }
}

- (NSDictionary<NSString *, NSString *> *)fixtureState:(XCUIApplication *)app {
    NSString *value = app.staticTexts[@"fixture.state"].value;
    NSMutableDictionary *state = [NSMutableDictionary dictionary];
    for (NSString *field in [value componentsSeparatedByString:@";"]) {
        NSArray *parts = [field componentsSeparatedByString:@"="];
        if (parts.count == 2) {
            state[parts[0]] = parts[1];
        }
    }
    return state;
}

- (CGRect)fixtureRect:(NSString *)value {
    NSString *numbers = [value stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"{}"]];
    NSArray<NSString *> *parts = [numbers componentsSeparatedByString:@","];
    XCTAssertEqual(parts.count, 4U);
    if (parts.count != 4) {
        return CGRectZero;
    }
    return CGRectMake(parts[0].doubleValue, parts[1].doubleValue, parts[2].doubleValue, parts[3].doubleValue);
}

- (void)tapFixtureControl:(NSString *)identifier app:(XCUIApplication *)app {
    NSInteger previousRevision = [self fixtureState:app][@"revision"].integerValue;
    [app.buttons[identifier] tap];
    NSPredicate *updated = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return [self fixtureState:app][@"revision"].integerValue > previousRevision;
    }];
    [self expectationForPredicate:updated evaluatedWithObject:app handler:nil];
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testNestedResizeAndAsymmetricSafeArea {
    XCUIApplication *app = [self launchAdaptiveFixture];
    CGRect initialLeft = app.buttons[@"fixture.nav.left"].frame;
    CGRect initialRight = app.buttons[@"fixture.nav.right"].frame;

    [self tapFixtureControl:@"fixture.leadingInset" app:app];
    CGRect leadingLeft = app.buttons[@"fixture.nav.left"].frame;
    CGRect leadingRight = app.buttons[@"fixture.nav.right"].frame;
    XCTAssertEqualWithAccuracy(CGRectGetMinX(leadingLeft) - CGRectGetMinX(initialLeft), 28, 0.5);
    XCTAssertEqualWithAccuracy(CGRectGetMaxX(leadingRight), CGRectGetMaxX(initialRight), 0.5);

    [self tapFixtureControl:@"fixture.trailingInset" app:app];
    CGRect trailingLeft = app.buttons[@"fixture.nav.left"].frame;
    CGRect trailingRight = app.buttons[@"fixture.nav.right"].frame;
    XCTAssertEqualWithAccuracy(CGRectGetMinX(trailingLeft), CGRectGetMinX(leadingLeft), 0.5);
    XCTAssertEqualWithAccuracy(CGRectGetMaxX(leadingRight) - CGRectGetMaxX(trailingRight), 36, 0.5);

    [self tapFixtureControl:@"fixture.resize" app:app];
    NSDictionary *state = [self fixtureState:app];
    CGRect container = [self fixtureRect:state[@"container"]];
    CGRect navigation = [self fixtureRect:state[@"nav"]];
    XCTAssertEqualWithAccuracy(CGRectGetWidth(navigation), CGRectGetWidth(container), 0.5);
    [self assertNavigationElements:app insideContainer:container state:state];
}

- (void)assertNavigationElements:(XCUIApplication *)app insideContainer:(CGRect)container state:(NSDictionary *)state {
    XCTAssertEqualObjects(state[@"titleIdentifier"], @"fixture.nav.title");
    XCTAssertEqualObjects(state[@"titleLabel"], @"Fixture navigation title");
    CGRect titleFrame = [self fixtureRect:state[@"title"]];
    [self assertFrame:titleFrame insideContainer:container];
    XCUIElement *title = app.staticTexts[@"fixture.nav.title"];
    if (titleFrame.size.width > 0) {
        XCTAssertTrue(title.exists);
        [self assertFrame:title.frame insideContainer:container];
        XCTAssertEqualObjects(title.label, @"Fixture navigation title");
    } else {
        XCTAssertEqual(titleFrame.size.width, 0);
    }
    for (NSString *identifier in @[@"fixture.nav.left", @"fixture.nav.subLeft", @"fixture.nav.right", @"fixture.nav.subRight"]) {
        XCUIElement *element = [app descendantsMatchingType:XCUIElementTypeAny][identifier];
        XCTAssertTrue(element.exists);
        [self assertFrame:element.frame insideContainer:container];
    }
}

- (void)assertFrame:(CGRect)frame insideContainer:(CGRect)container {
    XCTAssertGreaterThanOrEqual(CGRectGetWidth(frame), 0);
    XCTAssertGreaterThanOrEqual(CGRectGetHeight(frame), 0);
    XCTAssertGreaterThanOrEqual(CGRectGetMinX(frame), CGRectGetMinX(container) - 0.5);
    XCTAssertLessThanOrEqual(CGRectGetMaxX(frame), CGRectGetMaxX(container) + 0.5);
    XCTAssertGreaterThanOrEqual(CGRectGetMinY(frame), CGRectGetMinY(container) - 0.5);
    XCTAssertLessThanOrEqual(CGRectGetMaxY(frame), CGRectGetMaxY(container) + 0.5);
}

- (void)rotate:(UIDeviceOrientation)orientation app:(XCUIApplication *)app {
    NSInteger revision = [self fixtureState:app][@"revision"].integerValue;
    XCUIDevice.sharedDevice.orientation = orientation;
    NSPredicate *finished = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        NSDictionary *state = [self fixtureState:app];
        return [state[@"revision"] integerValue] > revision &&
            [state[@"landscape"] boolValue] == UIDeviceOrientationIsLandscape(orientation);
    }];
    [self expectationForPredicate:finished evaluatedWithObject:app handler:nil];
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)assertCurrentGeometry:(XCUIApplication *)app checkContent:(BOOL)checkContent {
    NSDictionary *state = [self fixtureState:app];
    CGRect container = [self fixtureRect:state[@"container"]];
    CGRect nav = [self fixtureRect:state[@"nav"]];
    XCTAssertEqualWithAccuracy(nav.size.width, container.size.width, 0.5, @"%@", state);
    XCTAssertEqualWithAccuracy(nav.size.height, [state[@"status"] doubleValue] + 44, 0.5, @"%@", state);
    [self assertNavigationElements:app insideContainer:container state:state];
    if (checkContent) {
        CGRect safe = [self fixtureRect:state[@"safe"]];
        XCTAssertEqualWithAccuracy([state[@"contentTop"] doubleValue], 12 + nav.size.height - safe.origin.x, 0.5, @"%@", state);
    }
}

- (void)testPortraitLandscapeAndPortraitConvergeToCurrentContainer {
    XCUIApplication *app = [self launchAdaptiveFixture];
    [self assertCurrentGeometry:app checkContent:YES];
    [self rotate:UIDeviceOrientationLandscapeLeft app:app];
    [self assertCurrentGeometry:app checkContent:YES];
    [self rotate:UIDeviceOrientationPortrait app:app];
    [self assertCurrentGeometry:app checkContent:YES];
    XCTAssertEqualObjects([self fixtureState:app][@"stack"], @"2");
}

- (void)testResizeThenRotateAndRotateThenResizeHaveSameFinalGeometry {
    XCUIApplication *app = [self launchAdaptiveFixture];
    [self assertCurrentGeometry:app checkContent:YES];
    [self tapFixtureControl:@"fixture.resize" app:app];
    [self assertCurrentGeometry:app checkContent:YES];
    [self rotate:UIDeviceOrientationLandscapeLeft app:app];
    NSDictionary *resizeThenRotate = [self fixtureState:app];
    [self assertCurrentGeometry:app checkContent:YES];
    [self rotate:UIDeviceOrientationPortrait app:app];
    [self assertCurrentGeometry:app checkContent:YES];
    [self tapFixtureControl:@"fixture.resize" app:app];
    [self assertCurrentGeometry:app checkContent:YES];
    [self rotate:UIDeviceOrientationLandscapeLeft app:app];
    [self assertCurrentGeometry:app checkContent:YES];
    [self tapFixtureControl:@"fixture.resize" app:app];
    NSDictionary *rotateThenResize = [self fixtureState:app];
    for (NSString *key in @[@"container", @"nav", @"title", @"contentTop", @"stack"]) {
        XCTAssertEqualObjects(resizeThenRotate[key], rotateThenResize[key], @"%@", key);
    }
    [self assertCurrentGeometry:app checkContent:YES];
    [self rotate:UIDeviceOrientationPortrait app:app];
    [self assertCurrentGeometry:app checkContent:YES];
}

- (void)testTableControllerPreservesScrollStateAcrossRotation {
    XCUIApplication *app = [self launchAdaptiveFixture];
    [self tapFixtureControl:@"fixture.tableMode" app:app];
    [self tapFixtureControl:@"fixture.scroll" app:app];
    CGFloat offset = [self fixtureState:app][@"offset"].doubleValue;
    XCTAssertGreaterThan(offset, 0);
    for (NSNumber *orientation in @[@(UIDeviceOrientationLandscapeLeft), @(UIDeviceOrientationPortrait)]) {
        [self rotate:orientation.integerValue app:app];
        [self assertCurrentGeometry:app checkContent:NO];
        NSDictionary *state = [self fixtureState:app];
        XCTAssertEqualWithAccuracy([state[@"offset"] doubleValue], offset, 0.5);
        XCTAssertEqualWithAccuracy([state[@"inset"] doubleValue], [state[@"status"] doubleValue] + 44, 0.5);
        CGRect container = [self fixtureRect:state[@"container"]];
        CGRect nav = [self fixtureRect:state[@"nav"]];
        XCTAssertEqualWithAccuracy(nav.origin.y, container.origin.y, 0.5);
        XCTAssertEqualObjects(state[@"stack"], @"3");
    }
}

- (void)testRotationDuringFoldPreservesTargetStateAndUpdatesWidth {
    XCUIApplication *app = [self launchAdaptiveFixture];
    [self tapFixtureControl:@"fixture.foldRotation" app:app];
    [self rotate:UIDeviceOrientationLandscapeLeft app:app];
    NSPredicate *completed = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return [self fixtureState:app][@"foldCompletions"].integerValue == 1;
    }];
    [self expectationForPredicate:completed evaluatedWithObject:app handler:nil];
    [self waitForExpectationsWithTimeout:10 handler:nil];
    NSDictionary *state = [self fixtureState:app];
    XCTAssertGreaterThan([state[@"foldSamples"] integerValue], 0);
    XCTAssertEqualWithAccuracy([state[@"foldWidthError"] doubleValue], 0, 0.5, @"%@", state);
    XCTAssertEqualObjects(state[@"folded"], @"1");
    [self rotate:UIDeviceOrientationPortrait app:app];
    state = [self fixtureState:app];
    CGRect nav = [self fixtureRect:state[@"nav"]];
    CGRect container = [self fixtureRect:state[@"container"]];
    XCTAssertEqualWithAccuracy(nav.size.width, container.size.width, 0.5);
    XCTAssertEqualWithAccuracy(nav.size.height, [state[@"status"] doubleValue], 0.5);
    XCTAssertEqualObjects(state[@"folded"], @"1");
    XCTAssertEqualObjects(state[@"foldCompletions"], @"1");
}

- (void)assertConstraintBlockReplacementInTableMode:(BOOL)tableMode {
    XCUIApplication *app = [self launchAdaptiveFixture];
    if (tableMode) { [self tapFixtureControl:@"fixture.tableMode" app:app]; }
    NSDictionary *initial = [self fixtureState:app];
    CGFloat height = [self fixtureRect:initial[@"nav"]].size.height;
    CGFloat safeTop = [self fixtureRect:initial[@"safe"]].origin.x;
    for (NSNumber *addition in @[@7, @19]) {
        NSInteger previousCalls = [self fixtureState:app][@"blockCalls"].integerValue;
        [self tapFixtureControl:@"fixture.constraintBlock" app:app];
        NSDictionary *state = [self fixtureState:app];
        XCTAssertEqual([state[@"blockCalls"] integerValue], previousCalls + 1, @"%@", state);
        XCTAssertEqualWithAccuracy([state[@"blockOriginal"] doubleValue], 12, 0.5);
        XCTAssertEqualWithAccuracy([state[@"blockProposed"] doubleValue], 12 + height, 0.5);
        XCTAssertEqualWithAccuracy([state[@"blockImmediate"] doubleValue], 12 + height + addition.doubleValue - safeTop, 0.5);
        XCTAssertEqualWithAccuracy([state[@"contentTop"] doubleValue], 12 + height + addition.doubleValue - safeTop, 0.5);
    }
}

- (void)testControllerConstraintBlockReplacementAfterInitialLayout {
    [self assertConstraintBlockReplacementInTableMode:NO];
}

- (void)testTableConstraintBlockReplacementAfterInitialLayout {
    [self assertConstraintBlockReplacementInTableMode:YES];
}

- (void)assertFinalOffsetCanReverseFoldInTableMode:(BOOL)tableMode {
    XCUIApplication *app = [self launchAdaptiveFixture];
    if (tableMode) { [self tapFixtureControl:@"fixture.tableMode" app:app]; }
    [self tapFixtureControl:@"fixture.reverseFold" app:app];
    NSPredicate *completed = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return [self fixtureState:app][@"newCompletion"].integerValue == 1;
    }];
    [self expectationForPredicate:completed evaluatedWithObject:app handler:nil];
    [self waitForExpectationsWithTimeout:10 handler:nil];
    NSDictionary *state = [self fixtureState:app];
    XCTAssertEqualObjects(state[@"reversed"], @"1");
    XCTAssertEqualObjects(state[@"oldCompletion"], @"0");
    XCTAssertEqualObjects(state[@"newCompletion"], @"1");
    XCTAssertGreaterThan([state[@"reverseOffsets"] integerValue], 0, @"%@", state);
    XCTAssertEqualWithAccuracy([state[@"reverseDistance"] doubleValue], 44, 0.5);
    XCTAssertEqualWithAccuracy([state[@"reverseHeight"] doubleValue], [state[@"status"] doubleValue] + 44, 0.5);
    XCTAssertEqualObjects(state[@"folded"], @"0");
    XCTAssertEqualObjects(state[@"callbacksOnMain"], @"1");
    [self assertCurrentGeometry:app checkContent:!tableMode];
    [self tapFixtureControl:@"fixture.resize" app:app];
    state = [self fixtureState:app];
    XCTAssertEqualObjects(state[@"oldCompletion"], @"0");
    XCTAssertEqualObjects(state[@"newCompletion"], @"1");
    XCTAssertEqualObjects(state[@"folded"], @"0");
}

- (void)testControllerFinalOffsetCallbackCanReverseFold {
    [self assertFinalOffsetCanReverseFoldInTableMode:NO];
}

- (void)testTableFinalOffsetCallbackCanReverseFold {
    [self assertFinalOffsetCanReverseFoldInTableMode:YES];
}

@end
