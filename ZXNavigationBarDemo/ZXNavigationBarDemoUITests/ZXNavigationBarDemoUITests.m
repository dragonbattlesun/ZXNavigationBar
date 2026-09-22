//
//  ZXNavigationBarDemoUITests.m
//  ZXNavigationBarDemoUITests
//
//  Created by 李兆祥 on 2020/3/7.
//  Copyright © 2020 ZXLee. All rights reserved.
//

#import <XCTest/XCTest.h>

static BOOL ZXAllowsSceneOrientationFallback(NSDictionary<NSString *, NSString *> *environment) {
    return [environment[@"XNAV_ALLOW_SCENE_ORIENTATION_FALLBACK"] isEqualToString:@"1"];
}

// 只允许显式授权的超时回退；其他等待错误也不得由 Scene 请求掩盖。
static BOOL ZXShouldRequestSceneOrientation(NSDictionary<NSString *, NSString *> *environment, XCTWaiterResult result) {
    return result == XCTWaiterResultTimedOut && ZXAllowsSceneOrientationFallback(environment);
}

@interface ZXNavigationBarDemoUITests : XCTestCase

@end

@implementation ZXNavigationBarDemoUITests

- (void)setUp {
    self.continueAfterFailure = NO;
}

- (void)testSceneOrientationFallbackRequiresExplicitOptIn {
    NSString *key = @"XNAV_ALLOW_SCENE_ORIENTATION_FALLBACK";
    for (NSDictionary *environment in @[@{}, @{key: @""}, @{key: @"0"}, @{key: @"true"}, @{key: @"01"}]) {
        XCTAssertFalse(ZXShouldRequestSceneOrientation(environment, XCTWaiterResultTimedOut), @"未精确 opt-in 时超时不得请求 Scene：%@", environment);
    }
    XCTAssertTrue(ZXShouldRequestSceneOrientation(@{key: @"1"}, XCTWaiterResultTimedOut));
    XCTAssertFalse(ZXShouldRequestSceneOrientation(@{key: @"1"}, XCTWaiterResultCompleted));
    XCTAssertFalse(ZXShouldRequestSceneOrientation(@{key: @"1"}, XCTWaiterResultInterrupted));
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
    // Scene 的实际方向可能跨启动保留；在展示任何历史浮层之前收敛到真实竖屏起点。
    if ([[self fixtureState:app][@"sceneLandscape"] boolValue]) {
        [self rotate:UIDeviceOrientationPortrait app:app];
    }
    NSDictionary *initial = [self fixtureState:app];
    NSLog(@"旋转基线：orientation=%@; window=%@; requests=%@", initial[@"sceneOrientation"], initial[@"window"], initial[@"rotationRequests"]);
    XCTAssertEqual([initial[@"sceneOrientation"] integerValue], UIInterfaceOrientationPortrait);
    return app;
}

- (void)testAdaptiveFixtureLaunchesWithoutChangingDefaultDemo {
    XCUIApplication *app = [self launchAdaptiveFixture];

    NSDictionary *state = [self fixtureState:app];
    [self assertNavigationElements:app insideContainer:[self fixtureRect:state[@"container"]] state:state];
    XCTAssertEqualObjects(app.buttons[@"fixture.nav.left"].label, @"Back");
}

- (NSDictionary *)historyState:(XCUIApplication *)app {
    NSString *value = app.staticTexts[@"fixture.history.geometry"].value;
    return [NSJSONSerialization JSONObjectWithData:[value dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

- (CGRect)historyRect:(NSArray<NSNumber *> *)value {
    XCTAssertEqual(value.count, 4U);
    return CGRectMake(value[0].doubleValue, value[1].doubleValue, value[2].doubleValue, value[3].doubleValue);
}

- (void)assertHistory:(XCUIApplication *)app unchanged:(NSDictionary *)initial {
    XCTAssertTrue(app.otherElements[@"fixture.history.overlay"].exists, @"旋转后必须保留原历史浮层");
    XCTAssertTrue(app.collectionViews[@"fixture.history.list"].exists);
    NSDictionary *state = [self historyState:app];
    NSLog(@"历史浮层几何：%@", state);
    for (NSString *key in @[@"overlay", @"list", @"data", @"titles", @"backIdentifier", @"backLabel"]) {
        XCTAssertEqualObjects(state[key], initial[key], @"%@", key);
    }
    XCTAssertTrue([state[@"attached"] boolValue]);
    XCTAssertEqualObjects(state[@"bounds"], state[@"container"]);
    XCTAssertEqualObjects(state[@"cover"], state[@"bounds"]);
    CGRect frame = [self historyRect:state[@"frame"]];
    CGRect safe = [self historyRect:state[@"safe"]];
    CGRect anchor = [self historyRect:state[@"anchor"]];
    [self assertFrame:frame insideContainer:safe];
    CGFloat expectedX = MIN(MAX(anchor.origin.x + 13, CGRectGetMinX(safe)), CGRectGetMaxX(safe) - frame.size.width);
    XCTAssertEqualWithAccuracy(frame.origin.x, expectedX, 0.5);
    XCTAssertEqualWithAccuracy(frame.origin.y, MIN(MAX(anchor.origin.y, CGRectGetMinY(safe)), CGRectGetMaxY(safe)), 0.5);
    XCTAssertEqualObjects(state[@"titles"], (@[@"Previous"]));
    XCTAssertEqualObjects(app.buttons[@"fixture.nav.left"].identifier, @"fixture.nav.left");
    XCTAssertEqualObjects(app.buttons[@"fixture.nav.left"].label, @"Back");
}

- (void)testHistoryOverlayStaysInCurrentWindowAcrossRotationAndResize {
    XCUIApplication *app = [self launchAdaptiveFixture];
    [self tapFixtureControl:@"fixture.history" app:app];
    XCTAssertTrue([app.collectionViews[@"fixture.history.list"] waitForExistenceWithTimeout:5]);
    NSDictionary *initial = [self historyState:app];
    [self assertHistory:app unchanged:initial];
    // 先验证旋转保持；旧实现会在真正方向通知后删除浮层。
    [self rotateWithHistory:UIDeviceOrientationLandscapeLeft app:app];
    [self assertHistory:app unchanged:initial];
    CGRect beforeResize = [self fixtureRect:[self fixtureState:app][@"container"]];
    [self tapFixtureControl:@"fixture.history.resize" app:app];
    [self assertHistory:app unchanged:initial];
    CGRect afterResize = [self fixtureRect:[self fixtureState:app][@"container"]];
    XCTAssertNotEqualWithAccuracy(beforeResize.size.width, afterResize.size.width, 0.5);
    [self rotateWithHistory:UIDeviceOrientationPortrait app:app];
    [self assertHistory:app unchanged:initial];
}

- (void)rotateWithHistory:(UIDeviceOrientation)orientation app:(XCUIApplication *)app {
    [self rotate:orientation app:app];
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

- (NSArray<NSString *> *)navigationAccessibilityIdentifiers {
    return @[
        @"fixture.nav.left",
        @"fixture.nav.subLeft",
        @"fixture.nav.title",
        @"fixture.nav.subRight",
        @"fixture.nav.right"
    ];
}

- (NSDictionary<NSString *, NSString *> *)expectedNavigationAccessibilityLabels {
    return @{
        @"fixture.nav.left": @"Back",
        @"fixture.nav.subLeft": @"Secondary back action",
        @"fixture.nav.title": @"Fixture navigation title",
        @"fixture.nav.subRight": @"Secondary action",
        @"fixture.nav.right": @"Primary action"
    };
}

- (XCUIElement *)navigationElementWithIdentifier:(NSString *)identifier app:(XCUIApplication *)app {
    return [app descendantsMatchingType:XCUIElementTypeAny][identifier];
}

- (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)navigationAccessibilitySnapshot:(XCUIApplication *)app {
    NSDictionary<NSString *, NSString *> *expectedLabels = [self expectedNavigationAccessibilityLabels];
    NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *snapshot = [NSMutableDictionary dictionary];
    for (NSString *identifier in [self navigationAccessibilityIdentifiers]) {
        XCUIElement *element = [self navigationElementWithIdentifier:identifier app:app];
        XCTAssertTrue(element.exists, @"辅助功能元素必须存在：%@", identifier);
        XCTAssertEqualObjects(element.identifier, identifier);
        XCTAssertEqualObjects(element.label, expectedLabels[identifier], @"辅助功能文案必须保持明确的英文标签：%@", identifier);
        XCTAssertTrue(element.enabled, @"辅助功能元素必须保持可用：%@", identifier);
        snapshot[identifier] = @{
            @"identifier": element.identifier ?: @"",
            @"label": element.label ?: @"",
            @"enabled": @(element.enabled)
        };
    }
    return snapshot;
}

- (void)assertNavigationAccessibilitySnapshot:(NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)snapshot
                              equalsBaseline:(NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)baseline {
    for (NSString *identifier in [self navigationAccessibilityIdentifiers]) {
        XCTAssertEqualObjects(snapshot[identifier], baseline[identifier], @"几何变化后辅助功能语义不得漂移：%@", identifier);
    }
}

- (void)assertNavigationAccessibilityOrder:(XCUIApplication *)app {
    NSMutableArray<XCUIElement *> *elements = [NSMutableArray array];
    for (NSString *identifier in [self navigationAccessibilityIdentifiers]) {
        [elements addObject:[self navigationElementWithIdentifier:identifier app:app]];
    }
    for (NSUInteger index = 1; index < elements.count; index++) {
        XCUIElement *previous = elements[index - 1];
        XCUIElement *current = elements[index];
        XCTAssertLessThan(CGRectGetMidX(previous.frame), CGRectGetMidX(current.frame),
                          @"最终物理 x 顺序必须为 leading actions、title、trailing actions：%@ -> %@",
                          previous.identifier, current.identifier);
    }
}

- (void)testAccessibilitySemanticsRemainStableAfterResizeAndRotation {
    XCUIApplication *app = [self launchAdaptiveFixture];
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *baseline = [self navigationAccessibilitySnapshot:app];
    NSDictionary<NSString *, NSString *> *initialState = [self fixtureState:app];
    CGRect initialContainer = [self fixtureRect:initialState[@"container"]];
    [self assertFrame:initialContainer insideContainer:[self fixtureRect:initialState[@"window"]]];

    [self tapFixtureControl:@"fixture.resize" app:app];
    NSDictionary<NSString *, NSString *> *resizedState = [self fixtureState:app];
    CGRect resizedContainer = [self fixtureRect:resizedState[@"container"]];
    XCTAssertNotEqualWithAccuracy(resizedContainer.origin.x, initialContainer.origin.x, 0.5);
    XCTAssertNotEqualWithAccuracy(resizedContainer.size.width, initialContainer.size.width, 0.5);
    [self assertFrame:resizedContainer insideContainer:[self fixtureRect:resizedState[@"window"]]];
    [self assertNavigationAccessibilitySnapshot:[self navigationAccessibilitySnapshot:app] equalsBaseline:baseline];

    [self rotate:UIDeviceOrientationLandscapeLeft app:app];
    [self assertNavigationAccessibilitySnapshot:[self navigationAccessibilitySnapshot:app] equalsBaseline:baseline];

    [self rotate:UIDeviceOrientationPortrait app:app];
    [self assertNavigationAccessibilitySnapshot:[self navigationAccessibilitySnapshot:app] equalsBaseline:baseline];
    [self assertNavigationAccessibilityOrder:app];
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
    NSDictionary *initial = [self fixtureState:app];
    NSDictionary *environment = NSProcessInfo.processInfo.environment;
    BOOL allowsSceneFallback = ZXAllowsSceneOrientationFallback(environment);
    NSInteger initialRequests = [initial[@"rotationRequests"] integerValue];
    if (!allowsSceneFallback) { XCTAssertEqual(initialRequests, 0); }
    NSInteger revision = [initial[@"revision"] integerValue];
    CGRect initialWindow = [self fixtureRect:initial[@"window"]];
    XCUIDevice.sharedDevice.orientation = orientation;
    NSPredicate *finished = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        NSDictionary *state = [self fixtureState:app];
        if (![state[@"rotationError"] isEqualToString:@"none"]) { return YES; }
        CGRect window = [self fixtureRect:state[@"window"]];
        return [state[@"revision"] integerValue] > revision &&
            [state[@"sceneLandscape"] boolValue] == UIDeviceOrientationIsLandscape(orientation) &&
            !CGSizeEqualToSize(window.size, initialWindow.size);
    }];
    XCTNSPredicateExpectation *deviceRotation = [[XCTNSPredicateExpectation alloc] initWithPredicate:finished object:app];
    XCTWaiterResult deviceResult = [XCTWaiter waitForExpectations:@[deviceRotation] timeout:2];
    BOOL requestedScene = ZXShouldRequestSceneOrientation(environment, deviceResult);
    if (deviceResult != XCTWaiterResultCompleted && !requestedScene) {
        XCTAssertEqual(deviceResult, XCTWaiterResultCompleted, @"XCUIDevice 旋转未收敛，禁止未显式 opt-in 的 Scene 回退；optIn=%d", allowsSceneFallback);
        return;
    }
    if (requestedScene) {
        // 仅测试进程显式 opt-in 时允许请求；仍要求真实窗口几何收敛。
        BOOL historyOpen = app.otherElements[@"fixture.history.overlay"].exists;
        NSString *identifier = [NSString stringWithFormat:@"%@.%@", historyOpen ? @"fixture.history.rotation" : @"fixture.rotation",
            UIDeviceOrientationIsLandscape(orientation) ? @"landscape" : @"portrait"];
        [app.buttons[identifier] tap];
    }
    XCTNSPredicateExpectation *sceneRotation = [[XCTNSPredicateExpectation alloc] initWithPredicate:finished object:app];
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[sceneRotation] timeout:10];
    NSDictionary *final = [self fixtureState:app];
    NSLog(@"旋转路径：optIn=%d; sceneFallback=%d; Scene requests %@ -> %@; window %@ -> %@; orientation %@ -> %@; error=%@", allowsSceneFallback, requestedScene, initial[@"rotationRequests"], final[@"rotationRequests"], initial[@"window"], final[@"window"], initial[@"sceneOrientation"], final[@"sceneOrientation"], final[@"rotationError"]);
    XCTAssertEqual([final[@"rotationRequests"] integerValue], initialRequests + (requestedScene ? 1 : 0));
    if (!allowsSceneFallback) { XCTAssertEqual([final[@"rotationRequests"] integerValue], 0); }
    XCTAssertEqualObjects(final[@"rotationError"], @"none");
    XCTAssertEqual(result, XCTWaiterResultCompleted);
    XCTAssertEqual([final[@"sceneLandscape"] boolValue], UIDeviceOrientationIsLandscape(orientation));
    XCTAssertFalse(CGSizeEqualToSize([self fixtureRect:final[@"window"]].size, initialWindow.size));
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
