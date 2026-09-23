#import "ZXNavigationBarGeometry.h"

@protocol ZXNavigationBarReservedRegionReading <NSObject>

@property (nonatomic, readonly) BOOL isActive;
@property (nonatomic, readonly) CGRect frame;

@end

__attribute__((visibility("hidden")))
NSArray<NSValue *> *ZXNavigationBarGeometryFilterActiveReservedRegionFrames(NSArray *regions) {
    NSMutableArray<NSValue *> *frames = [NSMutableArray array];
    for (id value in regions) {
        id<ZXNavigationBarReservedRegionReading> region = value;
        if (![region respondsToSelector:@selector(isActive)] ||
            ![region respondsToSelector:@selector(frame)]) {
            continue;
        }
        if (region.isActive && !CGRectIsEmpty(region.frame)) {
            [frames addObject:[NSValue valueWithCGRect:region.frame]];
        }
    }
    return frames;
}

UIEdgeInsets ZXNavigationBarSafeAreaInsetsForView(UIView *view) {
    if (!view) {
        return UIEdgeInsetsZero;
    }
    if (@available(iOS 11.0, *)) {
        if ([view respondsToSelector:@selector(safeAreaInsets)]) {
            return view.safeAreaInsets;
        }
    }
    return UIEdgeInsetsZero;
}

CGFloat ZXNavigationBarStatusBarHeightForView(UIView *view) {
    // 保留旧函数名以维持源码兼容；返回值只表达当前 View 自身承担的顶部安全区。
    // Scene / UIApplication 的全局状态栏高度会让已位于安全区内的嵌套 View 重复增高。
    return MAX(0, ZXNavigationBarSafeAreaInsetsForView(view).top);
}

NSArray<NSValue *> *ZXNavigationBarActiveReservedRegionFramesForView(UIView *view) {
#if defined(__IPHONE_27_1) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_27_1
    if (@available(iOS 27.1, *)) {
        SEL reservedRegionsSelector = @selector(reservedRegionsOfKind:);
        SEL occlusionKindSelector = @selector(occlusionRegionKind);
        SEL divisionKindSelector = @selector(divisionRegionKind);
        Class kindClass = UIViewReservedRegionKind.class;
        if (![view respondsToSelector:reservedRegionsSelector] ||
            ![kindClass respondsToSelector:occlusionKindSelector] ||
            ![kindClass respondsToSelector:divisionKindSelector]) {
            return @[];
        }

        id occlusionKind = [UIViewReservedRegionKind occlusionRegionKind];
        id divisionKind = [UIViewReservedRegionKind divisionRegionKind];
        NSMutableArray<NSValue *> *frames = [NSMutableArray array];
        for (id kind in @[occlusionKind, divisionKind]) {
            NSArray *regions = [view reservedRegionsOfKind:kind];
            [frames addObjectsFromArray:ZXNavigationBarGeometryFilterActiveReservedRegionFrames(regions)];
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

CGRect ZXNavigationBarConstrainHorizontalFrame(CGRect frame, CGRect segment) {
    CGFloat minX = CGRectGetMinX(segment);
    CGFloat maxX = minX + MAX(0, CGRectGetWidth(segment));
    CGFloat originX = MIN(maxX, MAX(minX, CGRectGetMinX(frame)));
    CGFloat endX = MIN(maxX, CGRectGetMinX(frame) + MAX(0, CGRectGetWidth(frame)));
    frame.origin.x = originX;
    frame.size.width = MAX(0, endX - originX);
    return frame;
}

CGRect ZXNavigationBarFitHorizontalFrame(CGRect preferredFrame, NSArray<NSValue *> *segments) {
    CGRect bestSegment = CGRectZero;
    CGFloat bestDistance = CGFLOAT_MAX;
    CGFloat anchorX = CGRectGetMinX(preferredFrame);
    for (NSValue *value in segments) {
        CGRect segment = value.CGRectValue;
        if (CGRectIsEmpty(segment)) {
            continue;
        }
        CGFloat distance = 0;
        if (anchorX < CGRectGetMinX(segment)) {
            distance = CGRectGetMinX(segment) - anchorX;
        } else if (anchorX > CGRectGetMaxX(segment)) {
            distance = anchorX - CGRectGetMaxX(segment);
        }
        if (distance < bestDistance) {
            bestDistance = distance;
            bestSegment = segment;
        }
    }
    if (bestDistance == CGFLOAT_MAX) {
        preferredFrame.size.width = 0;
        return preferredFrame;
    }

    CGFloat width = MIN(MAX(0, CGRectGetWidth(preferredFrame)), CGRectGetWidth(bestSegment));
    CGFloat minimumX = CGRectGetMinX(bestSegment);
    CGFloat maximumX = CGRectGetMaxX(bestSegment) - width;
    preferredFrame.origin.x = MIN(MAX(anchorX, minimumX), maximumX);
    preferredFrame.size.width = width;
    return preferredFrame;
}

NSArray<NSValue *> *ZXNavigationBarAvailableVerticalSegments(
    CGRect contentBounds,
    UIEdgeInsets safeAreaInsets,
    NSArray<NSValue *> *excludedFrames
) {
    CGFloat height = MAX(0, CGRectGetHeight(contentBounds) - safeAreaInsets.top - safeAreaInsets.bottom);
    CGRect safeBounds = CGRectMake(CGRectGetMinX(contentBounds),
                                   CGRectGetMinY(contentBounds) + safeAreaInsets.top,
                                   CGRectGetWidth(contentBounds),
                                   height);
    if (CGRectIsEmpty(safeBounds)) {
        return @[];
    }

    NSMutableArray<NSValue *> *clippedFrames = [NSMutableArray array];
    for (NSValue *value in excludedFrames) {
        CGRect excludedFrame = value.CGRectValue;
        if (CGRectIsEmpty(excludedFrame) ||
            CGRectGetMaxX(excludedFrame) <= CGRectGetMinX(contentBounds) ||
            CGRectGetMinX(excludedFrame) >= CGRectGetMaxX(contentBounds)) {
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
        if (CGRectGetMinY(leftFrame) < CGRectGetMinY(rightFrame)) {
            return NSOrderedAscending;
        }
        if (CGRectGetMinY(leftFrame) > CGRectGetMinY(rightFrame)) {
            return NSOrderedDescending;
        }
        if (CGRectGetMaxY(leftFrame) < CGRectGetMaxY(rightFrame)) {
            return NSOrderedAscending;
        }
        if (CGRectGetMaxY(leftFrame) > CGRectGetMaxY(rightFrame)) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];

    NSMutableArray<NSValue *> *mergedFrames = [NSMutableArray array];
    for (NSValue *value in clippedFrames) {
        CGRect frame = value.CGRectValue;
        CGRect previousFrame = mergedFrames.lastObject.CGRectValue;
        if (mergedFrames.count == 0 || CGRectGetMinY(frame) > CGRectGetMaxY(previousFrame)) {
            [mergedFrames addObject:value];
            continue;
        }

        CGFloat mergedMinY = CGRectGetMinY(previousFrame);
        CGFloat mergedMaxY = MAX(CGRectGetMaxY(previousFrame), CGRectGetMaxY(frame));
        mergedFrames[mergedFrames.count - 1] = [NSValue valueWithCGRect:CGRectMake(
            CGRectGetMinX(safeBounds),
            mergedMinY,
            CGRectGetWidth(safeBounds),
            mergedMaxY - mergedMinY
        )];
    }

    NSMutableArray<NSValue *> *segments = [NSMutableArray array];
    CGFloat cursorY = CGRectGetMinY(safeBounds);
    for (NSValue *value in mergedFrames) {
        CGRect frame = value.CGRectValue;
        if (CGRectGetMinY(frame) > cursorY) {
            [segments addObject:[NSValue valueWithCGRect:CGRectMake(
                CGRectGetMinX(safeBounds),
                cursorY,
                CGRectGetWidth(safeBounds),
                CGRectGetMinY(frame) - cursorY
            )]];
        }
        cursorY = MAX(cursorY, CGRectGetMaxY(frame));
    }
    if (cursorY < CGRectGetMaxY(safeBounds)) {
        [segments addObject:[NSValue valueWithCGRect:CGRectMake(
            CGRectGetMinX(safeBounds),
            cursorY,
            CGRectGetWidth(safeBounds),
            CGRectGetMaxY(safeBounds) - cursorY
        )]];
    }
    return segments;
}

CGRect ZXNavigationBarFitVerticalFrame(CGRect preferredFrame, NSArray<NSValue *> *segments) {
    CGRect bestSegment = CGRectZero;
    CGFloat bestDistance = CGFLOAT_MAX;
    CGFloat anchorY = CGRectGetMinY(preferredFrame);
    for (NSValue *value in segments) {
        CGRect segment = value.CGRectValue;
        if (CGRectIsEmpty(segment)) {
            continue;
        }
        CGFloat distance = 0;
        if (anchorY < CGRectGetMinY(segment)) {
            distance = CGRectGetMinY(segment) - anchorY;
        } else if (anchorY > CGRectGetMaxY(segment)) {
            distance = anchorY - CGRectGetMaxY(segment);
        }
        if (distance < bestDistance) {
            bestDistance = distance;
            bestSegment = segment;
        }
    }
    if (bestDistance == CGFLOAT_MAX) {
        preferredFrame.size.height = 0;
        return preferredFrame;
    }

    CGFloat height = MIN(MAX(0, CGRectGetHeight(preferredFrame)), CGRectGetHeight(bestSegment));
    CGFloat minimumY = CGRectGetMinY(bestSegment);
    CGFloat maximumY = CGRectGetMaxY(bestSegment) - height;
    preferredFrame.origin.y = MIN(MAX(anchorY, minimumY), maximumY);
    preferredFrame.size.height = height;
    return preferredFrame;
}

CGRect ZXNavigationBarTitleFrame(
    CGRect contentBounds,
    UIEdgeInsets safeAreaInsets,
    NSArray<NSValue *> *reservedFrames,
    NSArray<NSValue *> *buttonFrames,
    CGRect symmetricTitleFrame
) {
    NSArray<NSValue *> *unobstructedSegments = ZXNavigationBarAvailableHorizontalSegments(contentBounds, safeAreaInsets, @[]);
    NSArray<NSValue *> *availableSegments = ZXNavigationBarAvailableHorizontalSegments(contentBounds, safeAreaInsets, reservedFrames);
    // 行外或已在安全区之外的 region 不改变内容区，继续沿用对称居中。
    if ([availableSegments isEqualToArray:unobstructedSegments]) {
        return symmetricTitleFrame;
    }
    NSMutableArray<NSValue *> *titleExclusions = [reservedFrames mutableCopy];
    for (NSValue *value in buttonFrames) {
        CGRect frame = value.CGRectValue;
        if (CGRectGetWidth(frame) > 0) {
            // 按钮的水平占用贯穿内容行，保留既有标题避让语义。
            CGRect occupied = CGRectMake(CGRectGetMinX(frame), CGRectGetMinY(contentBounds),
                                         CGRectGetWidth(frame), CGRectGetHeight(contentBounds));
            [titleExclusions addObject:[NSValue valueWithCGRect:occupied]];
        }
    }
    return ZXNavigationBarLargestHorizontalSegment(
        ZXNavigationBarAvailableHorizontalSegments(contentBounds, safeAreaInsets, titleExclusions));
}
