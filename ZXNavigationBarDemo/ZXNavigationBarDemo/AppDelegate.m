//
//  AppDelegate.m
//  ZXNavigationBarDemo
//
//  Created by 李兆祥 on 2020/3/7.
//  Copyright © 2020 ZXLee. All rights reserved.
//

#import "AppDelegate.h"
#import "DemoAdaptiveLayoutViewController.h"
#import "DemoListViewController.h"
#import "ZXNavigationBarNavigationController.h"

static UIViewController *DemoRootViewController(void) {
    if ([[NSProcessInfo processInfo].arguments containsObject:@"ZXNavigationBarAdaptiveLayoutUITests"]) {
        return [[DemoAdaptiveLayoutViewController alloc] init];
    }
    DemoListViewController *controller = [[DemoListViewController alloc] init];
    return [[ZXNavigationBarNavigationController alloc] initWithRootViewController:controller];
}

API_AVAILABLE(ios(13.0))
@interface DemoSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation DemoSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) { return; }
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = DemoRootViewController();
    [self.window makeKeyAndVisible];
}
@end

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if (@available(iOS 13.0, *)) {
        // Scene delegate 持有窗口；避免同时创建旧生命周期窗口。
        return YES;
    }
    UIWindow *window = [[UIWindow alloc]initWithFrame:[UIScreen mainScreen].bounds];
    window.rootViewController = DemoRootViewController();
    [window makeKeyAndVisible];
    self.window = window;
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
