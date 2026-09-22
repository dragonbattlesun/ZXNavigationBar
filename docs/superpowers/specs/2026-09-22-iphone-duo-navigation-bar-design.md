# XNavigationBar iPhone Duo、旋转与窗口自适应设计

> 日期：2026-09-22
>
> 状态：已确认（用户于 2026-09-22 回复“继续”）
>
> 目标分支：`workflow/iphone-duo-adaptation`
>
> 基线：`origin/master@86388da2daa0c926608afa188f357eca6783d11a`

## 1. 背景与已确认决策

TalkMe 通过 CocoaPods 使用 `ZXNavigationBar`。当前库的自定义导航栏、控制器和历史导航栈浮层仍以 `UIScreen.main.bounds`、`UIApplication.keyWindow`、全局状态栏方向及对称横屏安全区计算布局。这些假设在嵌套容器、旋转、Split View、窗口 resize，以及 iPhone Duo 外屏、内屏和部分折叠姿态中会得到错误的宽度、状态栏高度或左右边距。

本次采用已确认的兼容方案：

1. 保留现有 ZX 自定义横向导航栏的视觉和公开使用方式，不在本次把整个库迁移到系统 `UINavigationBar`。
2. iOS 27.1 中，只有正在显示 ZX 自定义栏的控制器明确返回 `UIVerticalBarBehaviorDisabled`；使用系统导航栏或没有 ZX 自定义栏时保持 `UIVerticalBarBehaviorAutomatic`。
3. 旋转不是单独的设备方向分支，而是当前容器几何变化的一种。所有布局都以当前 View、WindowScene、safe area 和最终 `bounds` 为输入。
4. XNavigationBar Pod 的 deployment target 调整为 iOS 16.0；iOS 27.1 API 使用编译期、运行时与动态能力边界。TalkMe 下游验收仍按当前仓库规则以 iOS 17.0 为最低版本。
5. 本次不新增视觉尺寸、颜色、字体、图片或业务动作，只修复几何来源、系统竖向栏策略、旋转/resize 更新和历史浮层承载关系。

TalkMePRD 当前 `origin/main` 的 iPhone Duo V1.1 草案仍保留 iOS 16.0 表述。该版本现与本 Pod 的库级最低版本一致，但仍低于 TalkMeEnglish 当前 iOS 17.0 App 规则；下游集成和最终验收必须继续以 TalkMe 仓库规则为准，不能用 Pod 的 iOS 16.0 声明替代 App 的 iOS 17.0 证据。

## 2. 目标与非目标

### 2.1 目标

- 默认 ZX 导航栏宽度始终跟随所属控制器 `view.bounds.width`，不跟随物理屏幕宽度。
- 状态栏高度取自当前 `view.window.windowScene.statusBarManager`；左右安全区分别取当前 View 的 `safeAreaInsets.left/right`。
- iOS 27.1 中，标题与交互按钮避开与导航栏相交的 active division / occlusion reserved region；旧系统使用 safe-area 回退。
- 竖屏转横屏、横屏转竖屏、Duo 开合后旋转、部分折叠 resize、Split View 两侧 resize 后，导航栏、标题、左右按钮与历史浮层在最终布局周期内收敛到正确位置。
- iOS 27.1 的 ZX 自定义栏使用稳定的横向兼容模式，避免系统竖向状态栏与横向自定义栏同时出现；系统导航栏路径继续参与系统竖向栏布局。
- 固定高度、固定 frame、自定义 frame block、折叠动画、系统栏切换和历史栈能力保持兼容。
- 通过可重复的 Demo UI 测试验证嵌套容器、非对称安全区、旋转、resize、历史浮层和竖向栏回退策略。

### 2.2 非目标

- 不把 `ZXNavigationBar` 重写为系统 `UINavigationBar`，因此本次不会让 ZX 自定义按钮进入系统 vertical bar、overflow、`UIBarButtonItem.axisBehavior` 或系统可见性优先级。
- 不改变 TalkMe 的 Chat / VoiceChat 自定义业务栏；这些栏由 TalkMe 下游任务单独适配和验收。
- 不新增针对固定机型、Duo 型号或 `UIDeviceOrientation` 的布局分支。
- 不发布 CocoaPods 新版本、不创建 tag、不 push；TalkMe 首次集成使用本次库提交的精确 commit，发布动作另行确认。
- 不顺带修复 Demo 源码副本中已经存在的 `ZXNavItemBtn.m` 和 `ZXNavigationBarTableViewController.m` 历史差异。

## 3. 方案比较与选择

### 3.1 方案 A：保留自定义栏并做容器级自适应（采用）

将内部布局改为 View / Scene 范围的几何读取；iOS 27.1 下自定义栏明确关闭系统竖向栏，系统栏路径保持自动。优点是兼容现有调用方、改动范围可控、可在旧系统工作；代价是自定义栏仍不具备系统 vertical bar 和 overflow 能力。

### 3.2 方案 B：把库整体迁移到系统导航栏

可获得系统 vertical bar、overflow 和 reserved region 适配，但会改变自定义标题、折叠、渐变、历史栈和大量公开属性语义，属于破坏性重构，需要独立版本和完整视觉设计。本轮不采用。

### 3.3 方案 C：继续使用全局屏幕几何，仅增加方向通知

实现量小，但无法正确处理嵌套控制器、Duo、多 Scene、Split View 和无旋转事件的 resize，且仍会复用旧方向值。本轮不采用。

## 4. 架构与组件职责

### 4.1 View / Scene 范围的几何助手

在库内增加一个轻量、无状态的几何辅助层，输入具体 `UIView` 或 `UIViewController`，输出：

- 当前容器 `bounds`；
- 当前 View 的四边 safe area；
- 当前 WindowScene 的状态栏 frame / 高度；
- View 尚未进入 window 时的兼容回退值。

内部新代码不再读取 `ZXScreenWidth`、`ZXMainWindow`、`ZXIsHorizontalScreen` 或 `ZXHorizontaledSafeArea`。为保持源码兼容，现有公开宏本轮不删除；只停止在本次涉及的内部布局路径中使用，并在注释中标明新实现应使用带 View 上下文的助手。

回退顺序固定为：

1. `view.window.windowScene.statusBarManager.statusBarFrame`；
2. 当前 View 的 `safeAreaInsets.top`；
3. iOS 13 以下或 View 尚未入窗时使用现有 legacy 状态栏计算。

当 `bounds` 暂时为零时不把现有导航栏压成零宽，保留上一次有效几何并等待下一次布局回调。

### 4.2 `ZXNavigationBarController` 与 `ZXNavigationBarTableViewController`

两个控制器共享同一套更新规则：

- 默认 frame 的宽度来自 `self.view.bounds.size.width`；调用方设置的 `zx_navFixFrame` 仍拥有最高优先级。
- 默认高度由当前 scene 状态栏高度加现有内容栏高度组成；`zx_navFixHeight` 继续覆盖默认高度。
- `viewDidLayoutSubviews` 执行幂等几何更新；`viewSafeAreaInsetsDidChange` 请求下一轮更新，覆盖旋转、窗口 resize、Duo 开合、Split View 和系统栏变化。
- `viewWillTransitionToSize:withTransitionCoordinator:` 只负责在系统转场动画与结束点各触发一次布局收敛，不使用 `UIDeviceOrientation` 推导宽高。
- XIB 顶部约束和 TableView `contentInset` 使用同一轮当前导航栏高度与当前 View safe area 重算，不能继续减去全局 window 的 top inset。
- 当折叠动画进行中发生旋转或 resize 时，宽度和左右 safe area 立即更新，当前动画高度保持不变；动画完成后再以最终容器几何执行一次完整收敛，避免跳回旧宽度或重置折叠状态。

### 4.3 `ZXNavigationBar`

`ZXNavigationBar` 继续保持横向排列，但四边几何改为当前实例范围：

- 左按钮使用 `safeAreaInsets.left`，右按钮使用 `safeAreaInsets.right`，不再假设两边相等。
- 标题可用区继续按左右项目占用的较大值居中；结果宽度钳制为非负，窄容器中使用现有 label 截断行为，不产生负 frame。
- 状态栏垂直偏移来自当前 window scene；背景、分割线、渐变层和自定义栏跟随 `bounds`。
- 布局方法保持幂等；相同输入不重复产生可观察状态变化。

### 4.4 iOS 27.1 竖向系统栏策略

使用 Xcode 27.1 SDK 编译时，两个基类覆盖 `preferredVerticalBarBehavior`：

- ZX 自定义栏实际启用且可见：返回 `UIVerticalBarBehaviorDisabled`。
- `zx_showSystemNavBar == YES`、`zx_disableAutoSetCustomNavBar == YES`、`zx_hideBaseNavBar == YES` 或没有 ZX 自定义栏：返回系统默认的 automatic 行为。

相关代码用 `__IPHONE_OS_VERSION_MAX_ALLOWED` 编译守卫包裹，使 Xcode 27.0 及更早 SDK 不解析新类型；运行时由 API availability 保证旧系统不进入新行为。影响栏模式的已有 setter 和首次 `viewDidLoad` 在 iOS 27.1 调用 `setNeedsUpdateOfVerticalBarConfiguration`，但不依据临时页面状态频繁切换策略。

这是一项兼容回退，不等同于系统 vertical bar 适配。调用方改用系统导航栏后会自动恢复系统策略，不需要新增公开开关。

### 4.5 iOS 27.1 reserved region 避让

自定义栏不会获得系统容器的 fold avoidance，因此 iOS 27.1 路径从当前 `ZXNavigationBar` 查询 active occlusion 与 division reserved region，并转换到导航栏坐标系。几何辅助层把 safe-area 内的水平范围减去所有与导航栏内容行相交的 reserved frame，得到从左到右排列的可用区段。

布局规则固定为：

1. 左侧按钮组保持原顺序，从最左可用区段向内排列；右侧按钮组保持原顺序，从最右可用区段向内排列。
2. 标题放入扣除两侧按钮占用后宽度最大的可用区段；宽度相同则选择物理左侧区段，保证结果确定。
3. 标题宽度不足时沿用现有单行截断；可用宽度为零时标题 frame 宽度为零，但返回和主要动作不得被标题覆盖或移入 reserved region。
4. 外缘 occlusion 与 safe area 重复时取更严格边界，不重复累计同一避让距离。
5. inactive region 不参与当前 frame；姿态变化激活或停用 region 后，在同一布局收敛流程中重算。

区段计算实现为无状态矩形函数，输入 bounds、四边 safe area 与 reserved frame 数组，输出可用区段，便于用合成 division / occlusion frame 做确定性单元测试。实际 reserved region 查询和类型引用继续受 Xcode / iOS 27.1 可用性守卫保护；iOS 17.0 回退只使用 safe area。

### 4.6 历史导航栈浮层

历史浮层不再添加到进程级“主 Window”：

- 控制器从当前 `self.view.window` 传入承载 window，并把返回按钮 frame 转换到该 window 坐标系作为锚点。
- 浮层 frame 使用承载容器 `bounds`，cover view 使用自身 `bounds`，避免把 screen 坐标再次当作子视图坐标。
- 旋转或 resize 时浮层保持显示并重新计算锚点、safe area 和列表位置；不再仅因 `UIDeviceOrientationDidChangeNotification` 自动关闭。
- 承载 window 或锚点临时不可用时，本次展示安全失败或保持上一次有效位置，不跨 Scene 猜测其他 key window。

## 5. 旋转与 resize 数据流

```text
系统旋转 / Duo 开合 / Split View / 容器尺寸变化
  -> UIViewController 布局与 safe-area 生命周期回调
  -> 读取当前 view.bounds、view.safeAreaInsets、view.window.windowScene
  -> iOS 27.1 查询与栏内容相交的 active reserved regions
  -> 更新导航栏外框与内容 inset
  -> ZXNavigationBar 按 safe area 与可用区段重排按钮和标题
  -> 若历史浮层可见，按当前 window bounds 与转换后的锚点重排
  -> 转场完成后以最终 bounds 再收敛一次
```

整个流程只改变布局状态，不重新创建控制器、不修改导航栈、不发送业务请求，也不清空滚动、输入或调用方状态。

## 6. 兼容性与失败处理

- iOS 16.0～27.0：使用当前 View / WindowScene 范围几何与横向自定义栏，不引用 iOS 27.1 竖向栏 API。
- iOS 27.1：自定义栏关闭系统竖向栏；系统栏保持 automatic。
- iOS 27.1 reserved region 查询失败或尚未入窗：本轮使用当前 safe area，下一次有效布局自动重算；不跨 Scene 猜测 region。
- Xcode 27.0 编译：iOS 27.1 类型和方法被预处理排除。
- Xcode 27.1 编译：新 API 编译通过，Pod deployment target 保持 iOS 16.0。
- iOS 27 / 最新 SDK 启动：Apple 官方 TN3187 明确要求采用 UIKit scene-based lifecycle，否则 App 无法启动。Demo 使用单 `UIWindowScene` 的最小迁移，程序化 root 在 `scene:willConnectToSession:options:` 中创建；旧生命周期入口仅保留为旧系统回退，不扩展为多 Scene 业务改造。
- 多 Scene：只使用当前控制器所在 window，不跨 Scene 回退到任意窗口。
- 自定义 frame：调用方显式 frame/block 优先，库只负责在新的容器输入到来时再次调用既有 block。
- 旋转中折叠动画：不取消业务回调、不重置目标折叠态；仅更新与高度无关的几何，结束后最终校正。

## 7. 可访问性边界

本次不改变按钮标题、图片、动作或业务顺序。适配必须保证：

- 旋转 / resize 前后，已由调用方配置的 `accessibilityLabel`、traits、identifier 与 action 不丢失。
- VoiceOver / Switch Control 的元素顺序不因 frame 重算发生非确定性变化。
- 标题、返回和主要操作在左右非对称 safe area 后仍位于可见、可聚焦区域。
- Demo fixture 使用英文辅助功能文案和稳定 identifier；UI 自动化只补充几何与语义断言，不能替代后续 TalkMe 的 VoiceOver、Voice Control、Dynamic Type 和人工辅助技术验收。

导航按钮最小触控面积、所有历史页面的缺失标签及通用 Dynamic Type 改造属于独立无障碍审计；本次不在没有设计和调用方语义的情况下改变库的公开尺寸规则。

## 8. 测试设计

### 8.1 TDD 顺序

先增加失败测试，再修改库代码。新增轻量 Objective-C 单元测试 target 验证纯几何与 reserved-region 区段算法；Demo UI fixture 通过启动参数进入，不改变默认 Demo 流程。fixture 把 `ZXNavigationBarController` 放入可改变宽度和左右位置的子容器，并提供确定性的 resize、非对称 safe area、系统栏 / 自定义栏切换和历史浮层入口。

### 8.2 自动化用例

1. **嵌套容器宽度**：导航栏宽度等于子控制器 View 宽度，而不是 `UIScreen.main.bounds.width`。
2. **resize**：改变子容器宽度和 origin 后，导航栏、标题与按钮在一次布局周期内更新；导航栈和 fixture 状态不重置。
3. **非对称安全区**：分别增加 leading / trailing inset，左右按钮各自避让对应边，不使用同一个对称值。
4. **reserved region 区段**：使用合成 division / occlusion frame 验证区段相减、重叠去重、外缘收紧、inactive 排除、标题区段选择和零宽回退。
5. **竖屏转横屏、横屏转竖屏**：通过 `XCUIDevice.orientation` 执行双向旋转；导航栏宽度、按钮可见性和标题可用区在最终方向正确。
6. **旋转叠加 resize**：先 resize 再旋转、先旋转再 resize，最终 frame 只由最新容器几何决定。
7. **折叠动画中旋转**：触发栏折叠后立即旋转；宽度更新、动画目标高度和完成回调保持正确。
8. **历史浮层**：浮层挂载当前 window，旋转 / resize 后仍显示、cover 填满容器，列表锚定当前返回按钮且不跨 safe area。
9. **iOS 27.1 策略**：自定义栏 fixture 报告 disabled；系统导航栏 fixture 报告 automatic。
10. **可访问性稳定性**：旋转 / resize 前后关键控件 identifier、英文 label、enabled 状态与可聚焦顺序保持不变。

### 8.3 构建与回归矩阵

- Xcode 27.1 / iOS 27.1 iPhone Duo：运行上述 UI 用例，并在 Device Hub 可用时补充外屏、内屏、book-folded、tabletop、tent、Split View 左右和旋转截图。
- 当前稳定 Xcode 27.0：编译 Demo 和 Pod 源码，证明 iOS 27.1 符号被正确隔离。
- Demo lifecycle：在 iOS 17.0 与 iOS 27.1 分别验证默认 Demo 和带启动参数 fixture 均能进入正确 root，防止 Scene 迁移改变默认流程。
- Pod iOS 16.0：通过 podspec lint / build 验证库源码的 deployment target；不把 Xcode 27 的 XCTest/XCUIAutomation iOS 17.0 最低构建版本误算为 Pod 限制。
- iOS 17.0 Simulator：运行代表性 portrait / landscape / resize 回归，证明旧系统横向栏可工作。
- CocoaPods：执行本地 podspec lint / build；若网络或 CocoaPods 环境阻塞，保留原始失败并以 Demo 双工具链构建作为有限证据，不能声称 lint 通过。

## 9. 源码副本与集成策略

`ZXNavigationBar/` 是 Pod 的生产源码；Demo 工程当前编译 `ZXNavigationBarDemo/ZXNavigationBarDemo/ZXNavigationBar/` 副本。两者已有两处与本任务无关的历史差异，因此本轮：

1. 先修改生产源码并完成静态审查。
2. 只把本次 Duo / 旋转相关的同一补丁同步到 Demo 副本，不覆盖历史差异。
3. 通过 diff 核对“实施前已有差异 + 本次明确差异”，不得让本次涉及文件产生无法解释的新漂移。
4. Demo UI 测试验证镜像后的适配实现；TalkMe 随后通过 fork 的精确 commit 集成生产源码并执行 App 级回归。

本轮不重构 Demo 工程文件引用，也不删除任一源码树，避免把依赖结构迁移混入兼容修复。

## 10. TalkMe 下游交付

库实现、提交和 clean HEAD 验证完成后：

1. TalkMeEnglish 的 `Podfile` 使用 fork URL 和精确 commit，`Podfile.lock` 记录同一 SHA；不依赖未发布 tag。
2. 更新 TalkMePRD 导航栏现状：区分 ZXNavigationBar 基类、自定义 Chat 栏、自定义 VoiceChat 栏，并加入本次旋转矩阵。
3. 修正旧文档中的最低版本冲突，按当前规则使用 iOS 17.0 回退验收。
4. 在 TalkMe 分支专属 iOS 17.0 Simulator 与 iOS 27.1 Duo 上执行受影响页面构建、UI Smoke、旋转 / resize、截图和无障碍验收。
5. Device Hub、真实测试账号或真实后端仍不可用时，保持对应姿态截图和真实旅程为阻塞，不以 Demo 或单元测试替代。

## 11. 验收标准

- 生产源码不再在本次涉及的导航栏默认布局、safe area、状态栏和历史浮层路径中依赖全局 screen / key window。
- 自定义栏在 iOS 27.1 返回 disabled，系统栏返回 automatic；Xcode 27.0 仍可编译。
- portrait / landscape 双向旋转、嵌套容器、连续 resize、非对称 safe area 和 reserved-region 几何自动化通过。
- 旋转与 resize 不改变导航栈、折叠目标状态、按钮动作或辅助功能语义。
- 历史浮层绑定当前 scene/window，旋转后不消失、不越界、不跳到其他 Scene。
- Pod 以 iOS 16.0 deployment target 编译通过；iOS 17.0 回归可工作；iOS 27.1 Duo 实际姿态有明确通过证据或诚实的环境阻塞记录。
- 生产源码与 Demo 副本的本次适配补丁一致，历史差异未被顺手改写。
- 最终提交仅包含本任务文档、源码、Demo fixture / 测试及必要工程配置；工作树 clean，验证证据绑定最终 commit。
