/*  MTLView.mm
 *  WhirlyGlobeLib
 *
 *  Created by Steve Gifford on 5/20/19.
 *  Copyright 2011-2022 mousebird consulting
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

#import "MTLView.h"
#import "WhirlyKitLog.h"
#import "SceneRendererMTL.h"

using namespace WhirlyKit;

#if TARGET_OS_VISION
@implementation MTLView
{
}

+ (Class) layerClass
{
    return [CAMetalLayer class];
}

- (nonnull instancetype)initWithFrame:(CGRect)frameRect device:(nullable id<MTLDevice>)device
{
    self = [super initWithFrame:frameRect];
    self.mtlLayer.device = device;
    self.mtlLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    return self;
}

- (CAMetalLayer *)mtlLayer
{
    return (CAMetalLayer *)self.layer;
}

- (MTLPixelFormat) colorPixelFormat
{
    return self.mtlLayer.pixelFormat;
}

- (void) setColorPixelFormat:(MTLPixelFormat)colorPixelFormat
{
    self.mtlLayer.pixelFormat = colorPixelFormat;
}


//@property (nonatomic) MTLPixelFormat depthStencilPixelFormat;
//
//@property (nonatomic) MTLTextureUsage depthStencilAttachmentTextureUsage API_AVAILABLE(macos(10.15), ios(13.0));

- (void) setFramebufferOnly:(BOOL)framebufferOnly
{
    self.mtlLayer.framebufferOnly = framebufferOnly;
}

- (BOOL) framebufferOnly
{
    return self.mtlLayer.framebufferOnly;
}

//@property(nonatomic) NSInteger preferredFramesPerSecond;

- (id<CAMetalDrawable>) currentDrawable
{
    return [self.mtlLayer nextDrawable];
}

- (MTLRenderPassDescriptor *)currentRenderPassDescriptor
{
    MTLRenderPassDescriptor *passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    passDescriptor.colorAttachments[0].texture = [self.mtlLayer nextDrawable].texture;
    passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    
    // TODO: What about depth?
    
    return passDescriptor;
}

- (void)draw
{
}

@end
#endif

@interface WhirlyKitMTLView()<SceneRendererMTLDrawableGetter>
@end

@implementation WhirlyKitMTLView
{
    bool animating;
    bool loggedZeroDrawableSkip;   // edge-log the 0x0-drawable guard (Crashlytics 4da2a657)
}

// defined in WhirlyKitViewWrapper
@synthesize renderer;
@synthesize wrapperDelegate;

- (id)initWithDevice:(id<MTLDevice>)mtlDevice
{
    if (!(self = [super initWithFrame:CGRectZero device:mtlDevice]))
    {
        return nil;
    }

    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
    if (@available(iOS 13.0, *))
    {
        self.depthStencilAttachmentTextureUsage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    }
    self.framebufferOnly = true;
    animating = true;
    self.preferredFramesPerSecond = 120;

#if DEBUG
    if ([self.layer isKindOfClass:[CAMetalLayer class]])
    {
        CAMetalLayer *ml = (CAMetalLayer *)self.layer;
        ml.allowsNextDrawableTimeout = NO;
    }
#endif
    return self;
}

// Apparently they change this.  Because of course they can
- (void)setContentScaleFactor:(CGFloat)contentScaleFactor
{
    super.contentScaleFactor = contentScaleFactor;
    
    if (renderer)
        renderer->setScale(contentScaleFactor);
}

- (void)setRenderer:(WhirlyKit::SceneRenderer *)inRenderer
{
    SceneRendererMTL *renderMTL = dynamic_cast<SceneRendererMTL *>(inRenderer);
    if (!renderMTL)
        return;

    self->renderer = inRenderer;
    self->renderer->setScale(self.contentScaleFactor);

    renderMTL->setup(self.frame.size.width, self.frame.size.height,false);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (auto renderMTL = dynamic_cast<SceneRendererMTL *>(renderer))
    {
        const CGSize size = self.frame.size;
        const auto width = (int)(size.width * self.contentScaleFactor);
        const auto height = (int)(size.height * self.contentScaleFactor);
        if (width > 0 && height > 0)
        {
            if (renderMTL->resize(width, height))
            {
                [self.wrapperDelegate layoutDidRun];
            }
        }
        else
        {
            wkLogLevel(Debug, "Ignoring empty view resize");
        }
    }
}

- (id<CAMetalDrawable>)getDrawable
{
    return self.currentDrawable;
}

- (void)draw
{
    [super draw];
    
    SceneRendererMTL *renderMTL = dynamic_cast<SceneRendererMTL *>(renderer);
    if (!renderMTL)
        return;
    
    if (animating) {
        renderMTL->getView()->animate();

        if (renderMTL->hasChanges()) {
            renderMTL->updateZoomSlots();

            MTLRenderPassDescriptor *renderPassDesc = self.currentRenderPassDescriptor;
            if (!renderPassDesc)
                return;

            // Constrained-device wakes (memory-starved 3 GB iPad) can hand back a
            // non-nil render pass whose drawable came up 0x0 — a born-dead Metal
            // surface. Building a render pass against a 0x0 target aborts Metal
            // when the command encoder is torn down (Crashlytics 4da2a657). Skip
            // the frame; MTKView re-issues -draw on the next display link, so this
            // self-heals once the layer is actually sized. Edge-logged so a real
            // (or staging-forced) occurrence is visible without per-frame spam.
            id<MTLTexture> colorTex = renderPassDesc.colorAttachments[0].texture;
            if (!colorTex || colorTex.width == 0 || colorTex.height == 0) {
                if (!loggedZeroDrawableSkip) {
                    wkLogLevel(Warn, "WhirlyKitMTLView: 0x0 drawable — skipping frames (born-dead surface); self-heals on resize");
                    loggedZeroDrawableSkip = true;
                }
                return;
            }
            if (loggedZeroDrawableSkip) {
                wkLogLevel(Warn, "WhirlyKitMTLView: drawable resized — resuming render");
                loggedZeroDrawableSkip = false;
            }

            SceneRendererMTL::RenderInfoMTL info;
            info.renderPassDesc = renderPassDesc;
            info.drawGetter = self;
            renderMTL->render(1.0/self.preferredFramesPerSecond, &info);
        }
    } else {
        TimeInterval now = TimeGetCurrent();
        renderMTL->processScene(now);
    }
}

- (BOOL)isAnimating
{
    return animating;
}

- (void) startAnimation
{
    animating = true;
}

- (void) stopAnimation
{
    animating = false;
}

- (void) teardown
{
    self->renderer = nil;
}

@end
