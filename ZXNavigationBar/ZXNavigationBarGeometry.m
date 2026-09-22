#import "ZXNavigationBarGeometry.h"

UIEdgeInsets ZXNavigationBarSafeAreaInsetsForView(UIView *view) {
    return view ? view.safeAreaInsets : UIEdgeInsetsZero;
}

CGFloat ZXNavigationBarStatusBarHeightForView(UIView *view) {
    UIEdgeInsets safeAreaInsets = ZXNavigationBarSafeAreaInsetsForView(view);
    if (@available(iOS 13.0, *)) {
        CGFloat statusBarHeight = view.window.windowScene.statusBarManager.statusBarFrame.size.height;
        if (statusBarHeight > 0) {
            return statusBarHeight;
        }
    }
    if (safeAreaInsets.top > 0) {
        return safeAreaInsets.top;
    }
    if (@available(iOS 13.0, *)) {
        if (view.window) {
            return 0;
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return UIApplication.sharedApplication.statusBarFrame.size.height;
#pragma clang diagnostic pop
}

NSArray<NSValue *> *ZXNavigationBarActiveReservedRegionFramesForView(UIView *view) {
#if defined(__IPHONE_27_1) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_27_1
    if (@available(iOS 27.1, *)) {
        NSMutableArray<NSValue *> *frames = [NSMutableArray array];
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
        return frames;
    }
#endif
    return @[];
}

NSArray<NSValue *> *ZXNavigationBarAvailableHorizontalSegments(
    CGRect contentBounds,
    UIEdgeInsets safeAreaInsets,
    NSArray<NSValue *> *excludedFrames
) {
    CGFloat width = MAX(0, CGRectGetWidth(contentBounds) - safeAreaInsets.left - safeAreaInsets.right);
    CGRect safeBounds = CGRectMake(CGRectGetMinX(contentBounds) + safeAreaInsets.left,
                                   CGRectGetMinY(contentBounds),
                                   width,
                                   CGRectGetHeight(contentBounds));
    if (CGRectIsEmpty(safeBounds)) {
        return @[];
    }

    NSMutableArray<NSValue *> *clippedFrames = [NSMutableArray array];
    for (NSValue *value in excludedFrames) {
        CGRect excludedFrame = value.CGRectValue;
        if (CGRectIsEmpty(excludedFrame) ||
            CGRectGetMaxY(excludedFrame) <= CGRectGetMinY(contentBounds) ||
            CGRectGetMinY(excludedFrame) >= CGRectGetMaxY(contentBounds)) {
            continue;
        }

        CGRect clippedFrame = CGRectIntersection(excludedFrame, safeBounds);
        if (!CGRectIsEmpty(clippedFrame)) {
            [clippedFrames addObject:[NSValue valueWithCGRect:clippedFrame]];
        }
    }

    [clippedFrames sortUsingComparator:^NSComparisonResult(NSValue *leftValue, NSValue *rightValue) {
        CGRect leftFrame = leftValue.CGRectValue;
        CGRect rightFrame = rightValue.CGRectValue;
        if (CGRectGetMinX(leftFrame) < CGRectGetMinX(rightFrame)) {
            return NSOrderedAscending;
        }
        if (CGRectGetMinX(leftFrame) > CGRectGetMinX(rightFrame)) {
            return NSOrderedDescending;
        }
        if (CGRectGetMaxX(leftFrame) < CGRectGetMaxX(rightFrame)) {
            return NSOrderedAscending;
        }
        if (CGRectGetMaxX(leftFrame) > CGRectGetMaxX(rightFrame)) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];

    NSMutableArray<NSValue *> *mergedFrames = [NSMutableArray array];
    for (NSValue *value in clippedFrames) {
        CGRect frame = value.CGRectValue;
        CGRect previousFrame = mergedFrames.lastObject.CGRectValue;
        if (mergedFrames.count == 0 || CGRectGetMinX(frame) > CGRectGetMaxX(previousFrame)) {
            [mergedFrames addObject:value];
            continue;
        }

        CGFloat mergedMinX = CGRectGetMinX(previousFrame);
        CGFloat mergedMaxX = MAX(CGRectGetMaxX(previousFrame), CGRectGetMaxX(frame));
        mergedFrames[mergedFrames.count - 1] = [NSValue valueWithCGRect:CGRectMake(
            mergedMinX,
            CGRectGetMinY(safeBounds),
            mergedMaxX - mergedMinX,
            CGRectGetHeight(safeBounds)
        )];
    }

    NSMutableArray<NSValue *> *segments = [NSMutableArray array];
    CGFloat cursorX = CGRectGetMinX(safeBounds);
    for (NSValue *value in mergedFrames) {
        CGRect frame = value.CGRectValue;
        if (CGRectGetMinX(frame) > cursorX) {
            [segments addObject:[NSValue valueWithCGRect:CGRectMake(
                cursorX,
                CGRectGetMinY(safeBounds),
                CGRectGetMinX(frame) - cursorX,
                CGRectGetHeight(safeBounds)
            )]];
        }
        cursorX = MAX(cursorX, CGRectGetMaxX(frame));
    }
    if (cursorX < CGRectGetMaxX(safeBounds)) {
        [segments addObject:[NSValue valueWithCGRect:CGRectMake(
            cursorX,
            CGRectGetMinY(safeBounds),
            CGRectGetMaxX(safeBounds) - cursorX,
            CGRectGetHeight(safeBounds)
        )]];
    }
    return segments;
}

CGRect ZXNavigationBarLargestHorizontalSegment(NSArray<NSValue *> *segments) {
    CGRect largestSegment = CGRectZero;
    CGFloat largestWidth = 0;
    for (NSValue *value in segments) {
        CGRect segment = value.CGRectValue;
        if (CGRectGetWidth(segment) > largestWidth) {
            largestSegment = segment;
            largestWidth = CGRectGetWidth(segment);
        }
    }
    return largestSegment;
}
