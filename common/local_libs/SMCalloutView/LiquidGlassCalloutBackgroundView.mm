/*
 *  LiquidGlassCalloutBackgroundView.mm
 *  SMCalloutView
 *
 *  See header for description.
 */

#import "LiquidGlassCalloutBackgroundView.h"

@interface LiquidGlassCalloutBackgroundView ()
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) CAShapeLayer *strokeLayer;
@property (nonatomic, strong) CAShapeLayer *maskLayer;
@end

static const CGFloat kCornerRadius   = 8.0;
static const CGFloat kArrowWidth     = 22.0;
static const CGFloat kAnchorHeight   = 12.0;
static const CGFloat kAnchorMargin   = 24.0;

@implementation LiquidGlassCalloutBackgroundView

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.anchorHeight = kAnchorHeight;
        self.anchorMargin = kAnchorMargin;

        // System material blur — adapts to light/dark and picks up underlying
        // map content for the Liquid Glass effect.
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
        _blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        _blurView.userInteractionEnabled = NO;
        [self addSubview:_blurView];

        _maskLayer = [CAShapeLayer layer];
        _blurView.layer.mask = _maskLayer;

        // Subtle outline matching the SwiftUI overlay panels
        // (.primary.opacity(0.25) ≈ labelColor at 25% alpha).
        _strokeLayer = [CAShapeLayer layer];
        _strokeLayer.fillColor = [UIColor clearColor].CGColor;
        _strokeLayer.lineWidth = 1.0;
        _strokeLayer.strokeColor = [[UIColor labelColor] colorWithAlphaComponent:0.25].CGColor;
        [self.layer addSublayer:_strokeLayer];
    }
    return self;
}

- (void)setArrowPoint:(CGPoint)arrowPoint
{
    [super setArrowPoint:arrowPoint];
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    self.blurView.frame = self.bounds;

    UIBezierPath *path = [self calloutPath];
    self.maskLayer.frame = self.bounds;
    self.maskLayer.path = path.CGPath;
    self.strokeLayer.frame = self.bounds;
    self.strokeLayer.path = path.CGPath;
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    self.blurView.alpha = highlighted ? 0.85 : 1.0;
}

// Single continuous bezier path tracing the rounded-rect body and the
// triangular arrow as one outline (no internal seam between them).
- (UIBezierPath *)calloutPath
{
    const CGFloat width  = self.bounds.size.width;
    const CGFloat height = self.bounds.size.height;
    const CGFloat anchor = self.anchorHeight;
    const CGFloat r      = kCornerRadius;
    const CGFloat halfArrow = kArrowWidth / 2.0;
    const CGFloat tipX = self.arrowPoint.x;

    const BOOL pointingUp = self.arrowPoint.y < height / 2.0;

    UIBezierPath *path = [UIBezierPath bezierPath];

    if (pointingUp) {
        const CGFloat bodyTop = anchor;
        const CGFloat bodyBot = height;

        [path moveToPoint:CGPointMake(tipX - halfArrow, bodyTop)];
        [path addLineToPoint:CGPointMake(tipX, 0)];
        [path addLineToPoint:CGPointMake(tipX + halfArrow, bodyTop)];
        [path addLineToPoint:CGPointMake(width - r, bodyTop)];
        [path addArcWithCenter:CGPointMake(width - r, bodyTop + r)
                        radius:r
                    startAngle:-M_PI_2 endAngle:0 clockwise:YES];
        [path addLineToPoint:CGPointMake(width, bodyBot - r)];
        [path addArcWithCenter:CGPointMake(width - r, bodyBot - r)
                        radius:r
                    startAngle:0 endAngle:M_PI_2 clockwise:YES];
        [path addLineToPoint:CGPointMake(r, bodyBot)];
        [path addArcWithCenter:CGPointMake(r, bodyBot - r)
                        radius:r
                    startAngle:M_PI_2 endAngle:M_PI clockwise:YES];
        [path addLineToPoint:CGPointMake(0, bodyTop + r)];
        [path addArcWithCenter:CGPointMake(r, bodyTop + r)
                        radius:r
                    startAngle:M_PI endAngle:3*M_PI_2 clockwise:YES];
        [path closePath];
    } else {
        const CGFloat bodyTop = 0;
        const CGFloat bodyBot = height - anchor;

        [path moveToPoint:CGPointMake(r, bodyTop)];
        [path addLineToPoint:CGPointMake(width - r, bodyTop)];
        [path addArcWithCenter:CGPointMake(width - r, bodyTop + r)
                        radius:r
                    startAngle:-M_PI_2 endAngle:0 clockwise:YES];
        [path addLineToPoint:CGPointMake(width, bodyBot - r)];
        [path addArcWithCenter:CGPointMake(width - r, bodyBot - r)
                        radius:r
                    startAngle:0 endAngle:M_PI_2 clockwise:YES];
        [path addLineToPoint:CGPointMake(tipX + halfArrow, bodyBot)];
        [path addLineToPoint:CGPointMake(tipX, height)];
        [path addLineToPoint:CGPointMake(tipX - halfArrow, bodyBot)];
        [path addLineToPoint:CGPointMake(r, bodyBot)];
        [path addArcWithCenter:CGPointMake(r, bodyBot - r)
                        radius:r
                    startAngle:M_PI_2 endAngle:M_PI clockwise:YES];
        [path addLineToPoint:CGPointMake(0, bodyTop + r)];
        [path addArcWithCenter:CGPointMake(r, bodyTop + r)
                        radius:r
                    startAngle:M_PI endAngle:3*M_PI_2 clockwise:YES];
        [path closePath];
    }

    return path;
}

@end
