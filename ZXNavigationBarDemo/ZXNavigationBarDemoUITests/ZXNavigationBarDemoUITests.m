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

    XCTAssertTrue(app.staticTexts[@"fixture.nav.title"].exists);
    XCTAssertEqualObjects(app.buttons[@"fixture.nav.left"].label, @"Back");
}

@end
