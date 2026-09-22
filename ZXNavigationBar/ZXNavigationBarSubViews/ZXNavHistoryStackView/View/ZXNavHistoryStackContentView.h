//
//  ZXNavHistoryStackContentView.h
//  ZXNavigationBar
//
//  Created by 李兆祥 on 2020/12/22.
//  Copyright © 2020 ZXLee. All rights reserved.
//  https://github.com/SmileZXLee/ZXNavigationBar
//  V1.4.1

#import <UIKit/UIKit.h>
#import "ZXNavHistoryStackView.h"
#import "ZXNavHistoryStackModel.h"
NS_ASSUME_NONNULL_BEGIN


@interface ZXNavHistoryStackContentView : UIView
@property (strong, nonatomic) ZXNavHistoryStackView *zx_historyStackView;
@property (strong, nonatomic) NSMutableArray<ZXNavHistoryStackModel *> *zx_historyStackArray;
///导航栏历史堆栈视图与屏幕左侧的距离，与返回按钮与屏幕左侧的距离相同，交由内部处理，修改此属性无效
@property (assign, nonatomic) CGFloat zx_historyStackViewLeft;
///导航栏历史堆栈视图显示样式
@property (assign, nonatomic) ZXNavHistoryStackViewStyle zx_historyStackViewStyle;
- (instancetype)zx_show;
/// 在当前窗口所属容器中展示；锚点可为空，不推测其他 Scene 的窗口。
/// 始终返回 receiver。容器、非空锚点、所属窗口或几何无法安全展示时，
/// 保持未挂载或调用前的原状态；不能仅凭返回值非 nil 判断展示成功。
- (instancetype)zx_showInContainerView:(UIView *)containerView anchorView:(UIView * _Nullable)anchorView;
- (void)zx_hide;
@end

NS_ASSUME_NONNULL_END
