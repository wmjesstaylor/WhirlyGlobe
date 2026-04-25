/*
 *  LiquidGlassCalloutBackgroundView.h
 *  SMCalloutView
 *
 *  Translucent material-backed callout background — drop-in replacement for
 *  the default SMCalloutMaskedBackgroundView. Renders the body and arrow as
 *  a single continuous outline with a UIBlurEffect (system material) fill,
 *  so the callout adapts to underlying map content and dark mode.
 *
 *  Set on SMCalloutView.backgroundView, or via MaplyAnnotation's
 *  liquidGlassStyle property which configures it for you.
 */

#import <UIKit/UIKit.h>
#import "SMCalloutView.h"

NS_ASSUME_NONNULL_BEGIN

@interface LiquidGlassCalloutBackgroundView : SMCalloutBackgroundView
@end

NS_ASSUME_NONNULL_END
