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
