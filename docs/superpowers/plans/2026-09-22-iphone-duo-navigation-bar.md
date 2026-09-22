# XNavigationBar iPhone Duo 导航栏旋转适配 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 `ZXNavigationBar` 在普通 iPhone、iPhone Duo、多窗口、嵌套容器、连续 resize 和双向旋转后，始终按当前 View / WindowScene 的最终几何正确布局，并在 iOS 27.1 安全处理 vertical bar 与 reserved region。

**Architecture:** 新增无状态 `ZXNavigationBarGeometry` 作为唯一几何入口；两个控制器只负责生命周期收敛和栏模式决策；`ZXNavigationBar` 只负责把 safe area、reserved region 和按钮占用映射成 frame；历史浮层绑定调用控制器的当前 window。生产 Pod 源码先实现，Demo 副本只同步本任务补丁并保留既有差异。

**Tech Stack:** Objective-C、UIKit、XCTest / XCUITest、CocoaPods、Xcode 27.0 与 Xcode 27.1 SDK、iOS 17.0 Simulator、iOS 27.1 iPhone Duo Simulator。

## Global Constraints

- 规格单一事实源为 `docs/superpowers/specs/2026-09-22-iphone-duo-navigation-bar-design.md`；不得在实施中扩大为系统导航栏重写。
- `ZXNavigationBar.podspec` 的 iOS 8.0 deployment target 保持不变；Demo target 保持现状。TalkMe 的 iOS 17.0 下游约束不反向抬高 Pod 最低版本。
- 当前 Xcode 27.x 工具链只接受 iOS 15.0 及以上模拟器 deployment target；所有本计划 `xcodebuild` 验证命令显式传入 `IPHONEOS_DEPLOYMENT_TARGET=17.0`，该命令行覆盖不写回工程或 Pod 声明。
- iOS 27.1 类型必须同时受 `defined(__IPHONE_27_1)`、`__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_27_1` 和 `@available(iOS 27.1, *)` 保护，保证 Xcode 27.0 SDK 可编译。
- 不删除现有公开宏或公开属性；新实现停止在目标路径中使用 `ZXScreenWidth`、`ZXMainWindow`、`ZXHorizontaledSafeArea`、`ZXAppStatusBarHeight` 和 `UIApplication.keyWindow`。
- `ZXNavigationBar/` 是生产源码；`ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/` 是 Demo 镜像。每个生产补丁完成后，同步同一逻辑到镜像，不覆盖 `ZXNavItemBtn.m` 与 `ZXNavigationBarTableViewController.m` 的历史差异。
- 所有 UI 测试辅助功能文案使用英文；identifier 稳定且不参与多语言。
- 每个行为先写失败测试并保存首次失败摘要，再写最小实现；每个任务绿灯后独立提交。不得 push、merge、tag 或发布 Pod。
- 构建产物放到 `${TMPDIR%/}/ZXNavigationBar-workflow-iphone-duo-adaptation`，不污染仓库；测试设备按本分支创建，不复用其他 worktree 的专属模拟器。

---

### Task 1：建立双工具链测试入口与纯几何助手

**Files:**

- Create: `ZXNavigationBar/ZXNavigationBarGeometry.h`
- Create: `ZXNavigationBar/ZXNavigationBarGeometry.m`
- Create: `ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarGeometry.h`
- Create: `ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarGeometry.m`
- Create: `ZXNavigationBarDemo/ZXNavigationBarDemoTests/ZXNavigationBarGeometryTests.m`
- Create: `ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj/xcshareddata/xcschemes/ZXNavigationBarDemo.xcscheme`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj/project.pbxproj`

- [ ] **Step 1：在 Demo 工程增加逻辑单元测试 target**

  增加 `ZXNavigationBarDemoTests`，类型为 `com.apple.product-type.bundle.unit-test`，设置：

  ```text
  PRODUCT_BUNDLE_IDENTIFIER = cn.zxlee.ZXNavigationBarDemoTests
  GENERATE_INFOPLIST_FILE = YES
  IPHONEOS_DEPLOYMENT_TARGET = 9.0
  HEADER_SEARCH_PATHS = "$(PROJECT_DIR)/../ZXNavigationBar"
  CLANG_ENABLE_MODULES = YES
  ```

  target 的 Sources 只包含测试文件和生产目录的 `../ZXNavigationBar/ZXNavigationBarGeometry.m`，不复制待测实现。将 Demo 镜像的 `ZXNavigationBarGeometry.m` 加入 App target。共享 scheme 的 TestAction 同时包含 `ZXNavigationBarDemoTests` 和现有 `ZXNavigationBarDemoUITests`。

- [ ] **Step 2：声明唯一几何 API，并先写失败测试**

  `ZXNavigationBarGeometry.h` 的最终接口固定为：

  ```objc
  #import <UIKit/UIKit.h>

  NS_ASSUME_NONNULL_BEGIN

  FOUNDATION_EXPORT UIEdgeInsets ZXNavigationBarSafeAreaInsetsForView(UIView * _Nullable view);
  FOUNDATION_EXPORT CGFloat ZXNavigationBarStatusBarHeightForView(UIView * _Nullable view);
  FOUNDATION_EXPORT NSArray<NSValue *> *ZXNavigationBarActiveReservedRegionFramesForView(UIView *view);
  FOUNDATION_EXPORT NSArray<NSValue *> *ZXNavigationBarAvailableHorizontalSegments(
      CGRect contentBounds,
      UIEdgeInsets safeAreaInsets,
      NSArray<NSValue *> *excludedFrames
  );
  FOUNDATION_EXPORT CGRect ZXNavigationBarLargestHorizontalSegment(NSArray<NSValue *> *segments);

  NS_ASSUME_NONNULL_END
  ```

  单元测试至少覆盖以下输入；矩形比较统一使用 `XCTAssertEqualWithAccuracy(..., 0.5)`：

  ```objc
  - (void)testSafeAreaWithoutReservedRegionReturnsSingleSegment;
  - (void)testMiddleDivisionSplitsContentIntoTwoSegments;
  - (void)testOverlappingRegionsAreMergedBeforeSubtraction;
  - (void)testOuterOcclusionAndSafeAreaUseTheStricterBoundary;
  - (void)testRegionOutsideContentRowIsIgnored;
  - (void)testLargestSegmentBreaksTieTowardPhysicalLeft;
  - (void)testFullyOccludedContentReturnsNoSegment;
  #if defined(__IPHONE_27_1) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_27_1
  - (void)testReservedRegionQueryDropsInactiveRegions;
  #endif
  ```

  关键测试数据：

  ```objc
  CGRect content = CGRectMake(0, 20, 800, 44);
  UIEdgeInsets safe = UIEdgeInsetsMake(0, 24, 0, 40);
  NSArray *regions = @[
      [NSValue valueWithCGRect:CGRectMake(390, 0, 20, 100)]
  ];
  NSArray *segments = ZXNavigationBarAvailableHorizontalSegments(content, safe, regions);
  // 期望 {{24,20},{366,44}} 与 {{410,20},{350,44}}
  ```

- [ ] **Step 3：运行 RED，确认失败原因是算法尚未实现**

  先让实现临时只返回 safe bounds 单一区段，然后运行：

  ```bash
  export XNAV_DERIVED="${TMPDIR%/}/ZXNavigationBar-workflow-iphone-duo-adaptation"
  export XNAV_SIM17_NAME="B09-workflow-xnavigationbar-iphone-duo-adaptation-iPhone15-iOS17"
  if ! DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices available | rg -Fq "$XNAV_SIM17_NAME"; then
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl create "$XNAV_SIM17_NAME" com.apple.CoreSimulator.SimDeviceType.iPhone-15 com.apple.CoreSimulator.SimRuntime.iOS-17-0
  fi
  export XNAV_SIM17_UDID="$(DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices available | rg -F "$XNAV_SIM17_NAME" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' | head -1)"
  test -n "$XNAV_SIM17_UDID"
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
    -project ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj \
    -scheme ZXNavigationBarDemo \
    -derivedDataPath "$XNAV_DERIVED/stable" \
    -destination "platform=iOS Simulator,id=$XNAV_SIM17_UDID" \
    -only-testing:ZXNavigationBarDemoTests/ZXNavigationBarGeometryTests \
    IPHONEOS_DEPLOYMENT_TARGET=17.0 \
    test
  ```

  预期：测试 target 成功启动，但 division、overlap、outer occlusion、fully occluded 用例失败；不得接受 target 配置错误、链接错误或找不到测试作为 RED。

- [ ] **Step 4：实现最小确定性算法**

  `ZXNavigationBarAvailableHorizontalSegments` 按以下顺序实现：

  1. 仅用 `safeAreaInsets.left/right` 收紧 `contentBounds`，宽度钳制为非负。
  2. 丢弃空矩形和垂直方向不与内容行相交的矩形。
  3. 把 exclusion 裁剪到 safe bounds，按 `minX`、`maxX` 排序。
  4. 合并相交或相接矩形，再从左至右输出 gap。
  5. 无 gap 时返回空数组；最大区段遍历时只在 `width > currentWidth` 时更新，因此同宽自然选择物理左侧。

  iOS 27.1 查询只返回 active 的 occlusion / division frame：

  ```objc
  #if defined(__IPHONE_27_1) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_27_1
  if (@available(iOS 27.1, *)) {
      NSArray *kinds = @[
          [UIViewReservedRegionKind occlusionRegionKind],
          [UIViewReservedRegionKind divisionRegionKind]
      ];
      for (UIViewReservedRegionKind *kind in kinds) {
          for (UIViewReservedRegion *region in [view reservedRegionsOfKind:kind]) {
              if (region.isActive && !CGRectIsEmpty(region.frame)) {
                  [frames addObject:[NSValue valueWithCGRect:region.frame]];
              }
          }
      }
  }
  #endif
  ```

  `ZXNavigationBarStatusBarHeightForView` 的顺序为当前 `windowScene.statusBarManager`、当前 view safe-area top、仅用于未入窗/旧系统的 legacy status bar frame；不得查找其他 scene/window。

- [ ] **Step 5：同步 Demo 镜像并运行 GREEN**

  用同一补丁创建 Demo 两个几何文件，随后执行：

  ```bash
  diff -u ZXNavigationBar/ZXNavigationBarGeometry.h ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarGeometry.h
  diff -u ZXNavigationBar/ZXNavigationBarGeometry.m ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarGeometry.m
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
    -project ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj \
    -scheme ZXNavigationBarDemo \
    -derivedDataPath "$XNAV_DERIVED/stable" \
    -destination "platform=iOS Simulator,id=$XNAV_SIM17_UDID" \
    -only-testing:ZXNavigationBarDemoTests/ZXNavigationBarGeometryTests \
    IPHONEOS_DEPLOYMENT_TARGET=17.0 \
    test
  ```

  预期：两个 `diff` 无输出，全部几何测试通过。

- [ ] **Step 6：提交**

  ```bash
  git add ZXNavigationBar/ZXNavigationBarGeometry.h ZXNavigationBar/ZXNavigationBarGeometry.m \
    ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarGeometry.h \
    ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarGeometry.m \
    ZXNavigationBarDemo/ZXNavigationBarDemoTests/ZXNavigationBarGeometryTests.m \
    ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj/project.pbxproj \
    ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj/xcshareddata/xcschemes/ZXNavigationBarDemo.xcscheme
  git commit -m "test(iPhone Duo): 建立导航栏几何回归基线"
  ```

### Task 2：增加不影响默认 Demo 的自适应测试 fixture

**Files:**

- Create: `ZXNavigationBarDemo/ZXNavigationBarDemo/Demo/DemoAdaptiveLayoutViewController/DemoAdaptiveLayoutViewController.h`
- Create: `ZXNavigationBarDemo/ZXNavigationBarDemo/Demo/DemoAdaptiveLayoutViewController/DemoAdaptiveLayoutViewController.m`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemo/AppDelegate.m`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests.m`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj/project.pbxproj`

- [ ] **Step 1：实现可确定控制的嵌套容器**

  `DemoAdaptiveLayoutViewController` 作为普通容器控制器，内部持有 `ZXNavigationBarNavigationController`。导航栈预装一个 previous 页面和当前 `ZXNavigationBarController`，保证返回按钮与历史栈都有真实数据。child navigation controller 的 view 使用约束控制宽度和水平位置，不改 window 大小。

  fixture 提供以下按钮和稳定 identifier：

  ```text
  fixture.resize
  fixture.leadingInset
  fixture.trailingInset
  fixture.fold
  fixture.history
  fixture.systemBar
  fixture.tableMode
  fixture.nav.left
  fixture.nav.subLeft
  fixture.nav.title
  fixture.nav.subRight
  fixture.nav.right
  fixture.verticalBehavior
  fixture.state
  ```

  所有显式辅助功能文案使用英文，例如 `Resize container`、`Add leading safe area`、`Show navigation history`。fixture 的 state label 用可解析文本输出当前容器、导航栏和 safe area 数值，例如：

  ```text
  revision=1;container={x,y,w,h};nav={x,y,w,h};safe={top,left,bottom,right};mode=custom;folded=0
  ```

- [ ] **Step 2：只通过启动参数进入 fixture**

  `AppDelegate.m` 检查 `NSProcessInfo.processInfo.arguments` 是否包含 `ZXNavigationBarAdaptiveLayoutUITests`；包含时将 fixture 设为 root，否则保留原 `DemoListViewController` 流程。测试窗口仍只由 Demo 管理，不给生产库增加测试开关。

- [ ] **Step 3：把空 UI test 改为可复用启动器与 fixture smoke**

  ```objc
  - (XCUIApplication *)launchAdaptiveFixture {
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
  ```

  `setUp` 不再自动 launch 一个不可引用的临时 `XCUIApplication`；每个测试显式设置 portrait 并调用启动器。

- [ ] **Step 4：运行 smoke 并提交**

  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
    -project ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj \
    -scheme ZXNavigationBarDemo \
    -derivedDataPath "$XNAV_DERIVED/stable" \
    -destination "platform=iOS Simulator,id=$XNAV_SIM17_UDID" \
    -only-testing:ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests/testAdaptiveFixtureLaunchesWithoutChangingDefaultDemo \
    IPHONEOS_DEPLOYMENT_TARGET=17.0 \
    test
  git add ZXNavigationBarDemo/ZXNavigationBarDemo/Demo/DemoAdaptiveLayoutViewController \
    ZXNavigationBarDemo/ZXNavigationBarDemo/AppDelegate.m \
    ZXNavigationBarDemo/ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests.m \
    ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj/project.pbxproj
  git commit -m "test(Demo): 增加导航栏自适应测试入口"
  ```

### Task 3：让 `ZXNavigationBar` 避让非对称 safe area 与 reserved region

**Files:**

- Modify: `ZXNavigationBar/ZXNavigationBar.m`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBar.m`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests.m`
- Test: `ZXNavigationBarDemo/ZXNavigationBarDemoTests/ZXNavigationBarGeometryTests.m`

- [ ] **Step 1：增加 UI RED 用例**

  增加 `testNestedResizeAndAsymmetricSafeArea`：记录初始左右按钮 frame，依次点击 `fixture.leadingInset` 与 `fixture.trailingInset`，等待 `fixture.state` 更新，断言左按钮只响应 left inset、右按钮只响应 right inset；点击 `fixture.resize` 后断言 nav width 等于最新 container width、标题宽度非负且所有按钮 frame 位于 container 内。

  先在旧实现运行，预期至少出现以下失败：导航栏宽度仍等于 screen width；leading / trailing 使用同一横屏常量或完全不响应 synthetic safe area。

- [ ] **Step 2：用当前实例几何重写布局输入**

  `ZXNavigationBar.m` 导入 `ZXNavigationBarGeometry.h`，在 `relayoutSubviews` 中固定使用：

  ```objc
  CGFloat statusBarHeight = ZXNavigationBarStatusBarHeightForView(self);
  UIEdgeInsets safeAreaInsets = ZXNavigationBarSafeAreaInsetsForView(self);
  CGRect contentBounds = CGRectMake(0,
                                    statusBarHeight,
                                    CGRectGetWidth(self.bounds),
                                    MAX(0, CGRectGetHeight(self.bounds) - statusBarHeight));
  NSArray<NSValue *> *reservedFrames = ZXNavigationBarActiveReservedRegionFramesForView(self);
  NSArray<NSValue *> *segments = ZXNavigationBarAvailableHorizontalSegments(
      contentBounds, safeAreaInsets, reservedFrames);
  ```

  布局规则：

  - 主 left/right button 优先，sub button 次之；每个按钮宽度最多为所在最外区段的剩余宽度，绝不跨入 excluded frame。
  - 没有 reserved region 时保留原有“左右占用较大值决定标题对称 inset”的视觉语义。
  - 有 reserved region 时，把左右按钮占用矩形追加为 exclusion，重新计算标题 segments，选择最大区段；同宽取物理左侧。
  - 标题最终宽度使用 `MAX(0, width)`；可用宽度为零时保留对象和语义，只把 frame width 设为零。
  - `zx_bacImageView.frame`、gradient layer、line 和 custom bar 全部使用 `self.bounds`，避免把父坐标中的 `self.frame` 当作子视图坐标。
  - 不改 subview 添加顺序、不重建按钮、不覆盖已有 accessibility 属性。

- [ ] **Step 3：补窄区段和标题扣除的纯几何测试**

  在单元测试中增加：主按钮优先时 secondary action 收缩为零、左右占用后标题选择最大剩余区段、标题无区段时返回 `CGRectZero`。若需要复用计算，只向 `ZXNavigationBarGeometry.h/.m` 增加无 UI 状态的矩形函数，不能把按钮对象传入几何层。

- [ ] **Step 4：同步镜像、运行 GREEN 并提交**

  ```bash
  diff -u ZXNavigationBar/ZXNavigationBar.m ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBar.m
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
    -project ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj \
    -scheme ZXNavigationBarDemo \
    -derivedDataPath "$XNAV_DERIVED/stable" \
    -destination "platform=iOS Simulator,id=$XNAV_SIM17_UDID" \
    -only-testing:ZXNavigationBarDemoTests/ZXNavigationBarGeometryTests \
    -only-testing:ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests/testNestedResizeAndAsymmetricSafeArea \
    IPHONEOS_DEPLOYMENT_TARGET=17.0 \
    test
  git add ZXNavigationBar/ZXNavigationBar.m \
    ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBar.m \
    ZXNavigationBar/ZXNavigationBarGeometry.h ZXNavigationBar/ZXNavigationBarGeometry.m \
    ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarGeometry.h \
    ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarGeometry.m \
    ZXNavigationBarDemo/ZXNavigationBarDemoTests/ZXNavigationBarGeometryTests.m \
    ZXNavigationBarDemo/ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests.m
  git commit -m "fix(iPhone Duo): 避让导航栏安全区和保留区域"
  ```

### Task 4：让两个控制器在旋转、resize 与折叠期间收敛布局

**Files:**

- Modify: `ZXNavigationBar/ZXNavigationBarController.m`
- Modify: `ZXNavigationBar/ZXNavigationBarTableViewController.m`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarController.m`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarTableViewController.m`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemo/Demo/DemoAdaptiveLayoutViewController/DemoAdaptiveLayoutViewController.m`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests.m`

- [ ] **Step 1：增加旋转、顺序组合、Table 与折叠 RED 用例**

  新增以下 UI tests：

  ```objc
  - (void)testPortraitLandscapeAndPortraitConvergeToCurrentContainer;
  - (void)testResizeThenRotateAndRotateThenResizeHaveSameFinalGeometry;
  - (void)testTableControllerPreservesScrollStateAcrossRotation;
  - (void)testRotationDuringFoldPreservesTargetStateAndUpdatesWidth;
  ```

  每次动作后都等待 `fixture.state` 的 revision 增加，不使用固定 sleep。双向旋转必须实际设置 `XCUIDevice.sharedDevice.orientation` 为 landscapeLeft，再恢复 portrait。失败证据应显示旧实现的 nav width 仍取 `UIScreen.mainScreen.bounds`，或折叠中宽度没有更新。

- [ ] **Step 2：统一当前状态栏与默认 frame**

  两个控制器都导入几何助手并新增私有方法：

  ```objc
  - (CGFloat)zx_currentStatusBarHeight {
      return ZXNavigationBarStatusBarHeightForView(self.view);
  }

  - (CGFloat)getCurrentNavHeight {
      if (self.zx_navFixHeight != -1) {
          return self.zx_navFixHeight;
      }
      return [self zx_currentStatusBarHeight] + ZXNavBarHeightNotIncludeStatusBar;
  }
  ```

  默认 frame 的 width 只取 `self.view.bounds.size.width`。若 width 暂时为零，保持上次有效 frame 并返回；显式 `zx_navFixFrame` 始终拥有最高优先级；`zx_navHandleFrameBlock` 每次都接收基于最新容器生成的候选 frame。

  Table controller 不再因 `didDoScroll` 整体跳过 relayout：宽高始终更新，y 使用当前 `tableView.contentOffset.y`；只在 top inset 确实变化时更新 `contentInset`，并保持当前滚动状态。

- [ ] **Step 3：接入 UIKit 几何生命周期**

  两个控制器添加：

  ```objc
  - (void)viewSafeAreaInsetsDidChange {
      [super viewSafeAreaInsetsDidChange];
      [self.view setNeedsLayout];
  }

  - (void)viewWillTransitionToSize:(CGSize)size
         withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
      [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
      [coordinator animateAlongsideTransition:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) {
          [self.view setNeedsLayout];
          [self.view layoutIfNeeded];
      } completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) {
          [self relayoutSubviews];
          [self.view setNeedsLayout];
      }];
  }
  ```

  `viewDidLayoutSubviews` 始终更新 width/safe area；`isNavFoldAnimating` 为 YES 时保持当前 height，仅更新 width 和水平几何，动画结束后调用一次完整 `relayoutSubviews`。所有折叠阈值与 alpha 分母改用 `[self zx_currentStatusBarHeight]`，并保护除零。

- [ ] **Step 4：修复 XIB safe-area 与当前 window 归属**

  `updateTopConstraint:offset:checkSafeArea:` 只减 `ZXNavigationBarSafeAreaInsetsForView(self.view).top`。所有当前文件内的 `UIApplication.keyWindow.backgroundColor` 改为 `self.view.window.backgroundColor`（block 内使用 `weakSelf.view.window`）；window 不存在时不跨 scene 猜测。

  对已缓存的 XIB 原始约束，只有导航栏高度或 safe-area top 变化时才从 `orgOffset` 幂等重算，不累计差值。

- [ ] **Step 5：同步、运行 GREEN 并提交**

  先用 `diff -u` 核对 `ZXNavigationBarController.m` 完全一致；Table 文件允许且仅允许原有 scroll 相关历史差异。随后运行四个 UI tests 和全部 unit tests。

  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
    -project ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj \
    -scheme ZXNavigationBarDemo \
    -derivedDataPath "$XNAV_DERIVED/stable" \
    -destination "platform=iOS Simulator,id=$XNAV_SIM17_UDID" \
    -only-testing:ZXNavigationBarDemoTests \
    -only-testing:ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests/testPortraitLandscapeAndPortraitConvergeToCurrentContainer \
    -only-testing:ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests/testResizeThenRotateAndRotateThenResizeHaveSameFinalGeometry \
    -only-testing:ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests/testTableControllerPreservesScrollStateAcrossRotation \
    -only-testing:ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests/testRotationDuringFoldPreservesTargetStateAndUpdatesWidth \
    IPHONEOS_DEPLOYMENT_TARGET=17.0 \
    test
  git add ZXNavigationBar/ZXNavigationBarController.m ZXNavigationBar/ZXNavigationBarTableViewController.m \
    ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarController.m \
    ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarTableViewController.m \
    ZXNavigationBarDemo/ZXNavigationBarDemo/Demo/DemoAdaptiveLayoutViewController/DemoAdaptiveLayoutViewController.m \
    ZXNavigationBarDemo/ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests.m
  git commit -m "fix(旋转): 让导航栏跟随容器几何收敛"
  ```

### Task 5：接入 iOS 27.1 vertical bar 策略并保持 Xcode 27.0 编译

**Files:**

- Modify: `ZXNavigationBar/ZXNavigationBarController.m`
- Modify: `ZXNavigationBar/ZXNavigationBarTableViewController.m`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarController.m`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarTableViewController.m`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemo/Demo/DemoAdaptiveLayoutViewController/DemoAdaptiveLayoutViewController.m`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests.m`

- [ ] **Step 1：在 iOS 27.1 fixture 增加策略 RED**

  `fixture.verticalBehavior` 展示 `disabled`、`automatic` 或旧系统的 `unavailable`。新增 `testVerticalBarPolicyMatchesVisibleNavigationMode`：自定义栏断言 disabled；点击 `fixture.systemBar` 后断言 automatic；切回自定义栏时 fixture 必须依次设置 `zx_showSystemNavBar = NO` 与 `zx_hideBaseNavBar = NO`，再次断言 disabled，不能依赖现有 setter 自动恢复自定义栏。

  创建本分支 Duo simulator，不复用 TalkMe 其他分支设备：

  ```bash
  export XNAV_DUO_NAME="B09-workflow-xnavigationbar-iphone-duo-adaptation-iPhoneDuo"
  if ! DEVELOPER_DIR=/Applications/Xcode_beta.app/Contents/Developer xcrun simctl list devices available | rg -Fq "$XNAV_DUO_NAME"; then
    DEVELOPER_DIR=/Applications/Xcode_beta.app/Contents/Developer xcrun simctl create "$XNAV_DUO_NAME" com.apple.CoreSimulator.SimDeviceType.iPhone-Duo com.apple.CoreSimulator.SimRuntime.iOS-27-1
  fi
  export XNAV_DUO_UDID="$(DEVELOPER_DIR=/Applications/Xcode_beta.app/Contents/Developer xcrun simctl list devices available | rg -F "$XNAV_DUO_NAME" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' | head -1)"
  test -n "$XNAV_DUO_UDID"
  ```

- [ ] **Step 2：实现稳定模式决策**

  两个控制器增加相同的私有判断：

  ```objc
  - (BOOL)zx_usesVisibleCustomNavigationBar {
      return !self.zx_disableAutoSetCustomNavBar &&
             !self.zx_showSystemNavBar &&
             !self.zx_hideBaseNavBar &&
             self.zx_navBar != nil &&
             !self.zx_navBar.hidden;
  }
  ```

  新 API 全部放在编译守卫内：

  ```objc
  #if defined(__IPHONE_27_1) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_27_1
  - (UIVerticalBarBehavior)preferredVerticalBarBehavior {
      if (@available(iOS 27.1, *)) {
          return [self zx_usesVisibleCustomNavigationBar]
              ? UIVerticalBarBehaviorDisabled
              : UIVerticalBarBehaviorAutomatic;
      }
      return UIVerticalBarBehaviorAutomatic;
  }

  - (void)zx_requestVerticalBarConfigurationUpdate {
      if (@available(iOS 27.1, *)) {
          [self setNeedsUpdateOfVerticalBarConfiguration];
      }
  }
  #else
  - (void)zx_requestVerticalBarConfigurationUpdate {}
  #endif
  ```

  `viewDidLoad`、`setZx_hideBaseNavBar:`、`setZx_showSystemNavBar:` 与新增的 `setZx_disableAutoSetCustomNavBar:` 在状态真正变化后调用 request；不得根据旋转角度或临时 reserved region 切换策略。

- [ ] **Step 3：先验证 Xcode 27.0 编译，再验证 27.1 行为**

  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
    -project ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj \
    -scheme ZXNavigationBarDemo \
    -derivedDataPath "$XNAV_DERIVED/xcode-27-0" \
    -destination 'generic/platform=iOS Simulator' \
    IPHONEOS_DEPLOYMENT_TARGET=17.0 \
    CODE_SIGNING_ALLOWED=NO build
  DEVELOPER_DIR=/Applications/Xcode_beta.app/Contents/Developer xcodebuild \
    -project ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj \
    -scheme ZXNavigationBarDemo \
    -derivedDataPath "$XNAV_DERIVED/xcode-27-1" \
    -destination "platform=iOS Simulator,id=$XNAV_DUO_UDID" \
    -only-testing:ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests/testVerticalBarPolicyMatchesVisibleNavigationMode \
    IPHONEOS_DEPLOYMENT_TARGET=17.0 \
    test
  ```

  预期：27.0 不出现未知类型/selector 编译错误；27.1 三次模式断言全部通过。

- [ ] **Step 4：同步并提交**

  ```bash
  git add ZXNavigationBar/ZXNavigationBarController.m ZXNavigationBar/ZXNavigationBarTableViewController.m \
    ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarController.m \
    ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarTableViewController.m \
    ZXNavigationBarDemo/ZXNavigationBarDemo/Demo/DemoAdaptiveLayoutViewController/DemoAdaptiveLayoutViewController.m \
    ZXNavigationBarDemo/ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests.m
  git commit -m "feat(iOS 27.1): 配置自定义导航栏竖向栏回退"
  ```

### Task 6：让历史导航栈浮层绑定当前 window 并跟随旋转

**Files:**

- Modify: `ZXNavigationBar/ZXNavigationBarSubViews/ZXNavHistoryStackView/View/ZXNavHistoryStackContentView.h`
- Modify: `ZXNavigationBar/ZXNavigationBarSubViews/ZXNavHistoryStackView/View/ZXNavHistoryStackContentView.m`
- Modify: `ZXNavigationBar/ZXNavigationBarController.m`
- Modify: `ZXNavigationBar/ZXNavigationBarTableViewController.m`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarSubViews/ZXNavHistoryStackView/View/ZXNavHistoryStackContentView.h`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarSubViews/ZXNavHistoryStackView/View/ZXNavHistoryStackContentView.m`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarController.m`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarTableViewController.m`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemo/Demo/DemoAdaptiveLayoutViewController/DemoAdaptiveLayoutViewController.m`
- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests.m`

- [ ] **Step 1：增加 overlay 旋转 RED**

  新增 `testHistoryOverlayStaysInCurrentWindowAcrossRotationAndResize`：展示历史栈后断言 overlay/list 存在；旋转 landscape、执行 resize、恢复 portrait，每一步都断言 overlay 仍存在、cover 等于当前 container bounds、list 未越过 safe bounds，返回按钮 identifier/label 不变。

  旧实现预期在 `UIDeviceOrientationDidChangeNotification` 后自动移除 overlay，此失败即为正确 RED。

- [ ] **Step 2：增加带容器和锚点的展示入口，保留旧 API**

  Header 新增：

  ```objc
  - (instancetype)zx_showInContainerView:(UIView *)containerView
                              anchorView:(UIView * _Nullable)anchorView;
  ```

  `zx_show` 保留源码兼容，但只尝试从 `zx_historyStackArray` 中已加载控制器的 `view.window` 推导承载 view；找不到则安全返回，不读取进程级 key window。

  新方法保存 weak `containerView`/`anchorView`，展示时设置：

  ```objc
  self.frame = containerView.bounds;
  self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [containerView addSubview:self];
  ```

  首次展示时计算并保存 `anchorOffsetX = zx_historyStackViewLeft - anchorView.frame.origin.x`，从而兼容现有 offset 语义；后续每次 `layoutSubviews` 用 `[anchorView convertRect:anchorView.bounds toView:self]` 重算 x/y。list 的宽高分别钳制到 safe bounds 与可用高度，cover 始终使用 `self.bounds`。

- [ ] **Step 3：移除方向通知关闭逻辑并更新控制器调用**

  删除 `UIDeviceOrientationDidChangeNotification` 注册、`orientationDidChange:` 和对应 dealloc 清理。两个控制器展示前先取 `UIView *containerView = self.view.window`，为空则安全失败；继续设置原有 `zx_historyStackViewLeft` 和 style，然后调用：

  ```objc
  self.zx_navHistoryStackContentView =
      [view zx_showInContainerView:containerView anchorView:self.zx_navLeftBtn];
  ```

- [ ] **Step 4：同步、运行 GREEN 并提交**

  ```bash
  DEVELOPER_DIR=/Applications/Xcode_beta.app/Contents/Developer xcodebuild \
    -project ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj \
    -scheme ZXNavigationBarDemo \
    -derivedDataPath "$XNAV_DERIVED/xcode-27-1" \
    -destination "platform=iOS Simulator,id=$XNAV_DUO_UDID" \
    -only-testing:ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests/testHistoryOverlayStaysInCurrentWindowAcrossRotationAndResize \
    IPHONEOS_DEPLOYMENT_TARGET=17.0 \
    test
  git add ZXNavigationBar/ZXNavigationBarSubViews/ZXNavHistoryStackView/View/ZXNavHistoryStackContentView.h \
    ZXNavigationBar/ZXNavigationBarSubViews/ZXNavHistoryStackView/View/ZXNavHistoryStackContentView.m \
    ZXNavigationBar/ZXNavigationBarController.m ZXNavigationBar/ZXNavigationBarTableViewController.m \
    ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarSubViews/ZXNavHistoryStackView/View/ZXNavHistoryStackContentView.h \
    ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarSubViews/ZXNavHistoryStackView/View/ZXNavHistoryStackContentView.m \
    ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarController.m \
    ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarTableViewController.m \
    ZXNavigationBarDemo/ZXNavigationBarDemo/Demo/DemoAdaptiveLayoutViewController/DemoAdaptiveLayoutViewController.m \
    ZXNavigationBarDemo/ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests.m
  git commit -m "fix(历史栈): 绑定当前窗口并支持旋转重排"
  ```

### Task 7：补齐辅助功能回归、文档与源码镜像审计

**Files:**

- Modify: `ZXNavigationBarDemo/ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests.m`
- Modify: `README.md`

- [ ] **Step 1：增加语义稳定性测试**

  新增 `testAccessibilitySemanticsRemainStableAfterResizeAndRotation`。在 portrait 记录五个关键元素的 identifier、English label、enabled；resize、landscape、portrait 后逐一比较。再按最终 frame 的物理 x 验证 leading actions 在 title 前、trailing actions在 title 后；不以重建 accessibility element 的方式制造通过。

- [ ] **Step 2：更新 README 兼容性说明**

  增加 “iPhone Duo、旋转与多窗口” 小节，明确：

  - 无公开调用方式迁移；默认 frame 已改为当前控制器 bounds。
  - iOS 27.1 自定义栏使用 horizontal fallback，系统栏保持 automatic。
  - reserved region 在 27.1 SDK 生效，旧系统使用 safe area。
  - Pod 最低版本仍为 iOS 8.0；建议 TalkMe 等下游以精确 commit 集成后自行完成业务页面验收。

- [ ] **Step 3：审计全局几何与镜像漂移**

  ```bash
  rg -n 'ZXScreenWidth|ZXMainWindow|ZXHorizontaledSafeArea|ZXAppStatusBarHeight|\[UIScreen mainScreen\]|keyWindow' \
    ZXNavigationBar/ZXNavigationBar.m \
    ZXNavigationBar/ZXNavigationBarController.m \
    ZXNavigationBar/ZXNavigationBarTableViewController.m \
    ZXNavigationBar/ZXNavigationBarSubViews/ZXNavHistoryStackView/View/ZXNavHistoryStackContentView.m
  diff -u ZXNavigationBar/ZXNavigationBarGeometry.h ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarGeometry.h
  diff -u ZXNavigationBar/ZXNavigationBarGeometry.m ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarGeometry.m
  diff -u ZXNavigationBar/ZXNavigationBar.m ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBar.m
  diff -u ZXNavigationBar/ZXNavigationBarController.m ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarController.m
  diff -u ZXNavigationBar/ZXNavigationBarSubViews/ZXNavHistoryStackView/View/ZXNavHistoryStackContentView.h ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarSubViews/ZXNavHistoryStackView/View/ZXNavHistoryStackContentView.h
  diff -u ZXNavigationBar/ZXNavigationBarSubViews/ZXNavHistoryStackView/View/ZXNavHistoryStackContentView.m ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarSubViews/ZXNavHistoryStackView/View/ZXNavHistoryStackContentView.m
  git diff --exit-code origin/master -- ZXNavigationBar/ZXNavigationBarSubViews/ZXNavItemBtn.m ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarSubViews/ZXNavItemBtn.m
  diff -u ZXNavigationBar/ZXNavigationBarTableViewController.m ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/ZXNavigationBarTableViewController.m
  ```

  预期：`rg` 无匹配；前六个 `diff` 无输出；`ZXNavItemBtn.m` 相对基线无本任务改动；最后一个 Table diff 只保留实施前已知 scroll 历史差异和路径一致的本任务上下文，不出现新的单边 Duo 逻辑。

- [ ] **Step 4：运行辅助功能测试并提交**

  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
    -project ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj \
    -scheme ZXNavigationBarDemo \
    -derivedDataPath "$XNAV_DERIVED/stable" \
    -destination "platform=iOS Simulator,id=$XNAV_SIM17_UDID" \
    -only-testing:ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests/testAccessibilitySemanticsRemainStableAfterResizeAndRotation \
    IPHONEOS_DEPLOYMENT_TARGET=17.0 \
    test
  git add README.md ZXNavigationBarDemo/ZXNavigationBarDemoUITests/ZXNavigationBarDemoUITests.m
  git commit -m "test(无障碍): 固化旋转后的导航栏语义"
  ```

### Task 8：在 clean HEAD 上完成双版本、Duo 姿态和 Pod 验证

**Files:**

- 仅验证，不修改仓库文件。

- [ ] **Step 1：先确认提交范围与 clean HEAD**

  ```bash
  export XNAV_FINAL_SHA="$(git rev-parse HEAD)"
  export XNAV_EVIDENCE_DIR="$XNAV_DERIVED/evidence/$XNAV_FINAL_SHA"
  mkdir -p "$XNAV_EVIDENCE_DIR"
  git status --short --branch
  git diff --check origin/master...HEAD
  git diff --stat origin/master...HEAD
  git log --oneline --decorate origin/master..HEAD
  ```

  预期：工作树 clean；只包含规格、计划、目标源码、Demo fixture/tests、工程配置与 README。

- [ ] **Step 2：运行 iOS 17.0 全量单元与 UI 回归**

  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl boot "$XNAV_SIM17_UDID" 2>/dev/null || true
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
    -project ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj \
    -scheme ZXNavigationBarDemo \
    -configuration Debug \
    -derivedDataPath "$XNAV_DERIVED/final-ios17" \
    -destination "platform=iOS Simulator,id=$XNAV_SIM17_UDID" \
    IPHONEOS_DEPLOYMENT_TARGET=17.0 \
    test
  ```

  预期：unit 与 UI tests 全部通过；portrait/landscape 往返后的最后状态仍是 portrait，避免污染后续场景。

- [ ] **Step 3：运行 Xcode 27.0 / 27.1 编译矩阵**

  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
    -project ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj \
    -scheme ZXNavigationBarDemo \
    -configuration Release \
    -derivedDataPath "$XNAV_DERIVED/final-xcode-27-0" \
    -destination 'generic/platform=iOS Simulator' \
    IPHONEOS_DEPLOYMENT_TARGET=17.0 \
    CODE_SIGNING_ALLOWED=NO build
  DEVELOPER_DIR=/Applications/Xcode_beta.app/Contents/Developer xcodebuild \
    -project ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj \
    -scheme ZXNavigationBarDemo \
    -configuration Release \
    -derivedDataPath "$XNAV_DERIVED/final-xcode-27-1" \
    -destination 'generic/platform=iOS Simulator' \
    IPHONEOS_DEPLOYMENT_TARGET=17.0 \
    CODE_SIGNING_ALLOWED=NO build
  DEVELOPER_DIR=/Applications/Xcode_beta.app/Contents/Developer xcodebuild \
    -project ZXNavigationBarDemo/ZXNavigationBarDemo.xcodeproj \
    -scheme ZXNavigationBarDemo \
    -derivedDataPath "$XNAV_DERIVED/final-duo" \
    -destination "platform=iOS Simulator,id=$XNAV_DUO_UDID" \
    IPHONEOS_DEPLOYMENT_TARGET=17.0 \
    test
  ```

- [ ] **Step 4：执行 iPhone Duo 姿态、旋转与截图验收**

  在 Xcode 27.1 Device Hub 中只选择 `$XNAV_DUO_UDID`，运行 `ZXNavigationBarAdaptiveLayoutUITests` fixture。按顺序检查并截图：closed 外屏 portrait/landscape、open 内屏 portrait/landscape、book-folded、tabletop、tent，以及每种可用姿态下的 custom/system bar 切换、resize、history overlay。每张截图必须同时看到标题、左右动作和 `fixture.state`，以 `<pose>-<orientation>-<scenario>-$XNAV_FINAL_SHA.png` 命名并导出到 `$XNAV_EVIDENCE_DIR`。

  自动化至少覆盖双向旋转；Device Hub 若不提供某姿态或截图接口，保留原始界面/工具错误，把该姿态标为环境阻塞，不能用普通 iPhone 截图冒充。

- [ ] **Step 5：人工辅助技术检查**

  在 Duo open portrait、open landscape 与 book-folded 各执行一次 VoiceOver/Voice Control 检查：Back、leading secondary、title、trailing secondary、trailing primary 的英文 label、enabled、action 均保持；旋转后焦点元素仍存在且未被 reserved region 遮挡。将 Dynamic Type 调至最大辅助尺寸，确认 frame 不为负、动作仍可聚焦；本轮不承诺重构库的固定字号。

- [ ] **Step 6：执行 Pod lint 并保存有限证据**

  ```bash
  pod lib lint ZXNavigationBar.podspec --allow-warnings --verbose
  ```

  预期：lint 通过且 deployment target 仍为 8.0。若 CocoaPods 网络/环境失败，保存首次错误；只能汇报“Demo 双工具链构建通过、Pod lint 环境阻塞”，不得声称 lint 通过。

- [ ] **Step 7：绑定最终 SHA 并清理本任务资源**

  ```bash
  git status --porcelain
  test -z "$(git status --porcelain)"
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl shutdown "$XNAV_SIM17_UDID" 2>/dev/null || true
  DEVELOPER_DIR=/Applications/Xcode_beta.app/Contents/Developer xcrun simctl shutdown "$XNAV_DUO_UDID" 2>/dev/null || true
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl delete "$XNAV_SIM17_UDID"
  DEVELOPER_DIR=/Applications/Xcode_beta.app/Contents/Developer xcrun simctl delete "$XNAV_DUO_UDID"
  ```

  最终汇报必须区分：自动化已通过、实际姿态已截图、人工辅助技术已检查、Pod lint 已通过或明确阻塞。向 TalkMe 下游只提供 `$XNAV_FINAL_SHA` 精确 commit；不创建 tag，不修改 Pod version，不自动 push。
