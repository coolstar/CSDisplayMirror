//
//  CSDisplayMirror.m
//  CSDisplayMirror
//
//  Created by CoolStar on 6/29/13.
//  Copyright (c) 2013 CoolStar. All rights reserved.
//

#import "CSDisplayMirror.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreGraphics/CoreGraphics.h>

NSString * const UIApplicationDidSetupScreenMirroringNotification = @"UIApplicationDidSetupScreenMirroringNotification";
NSString * const UIApplicationDidDisableScreenMirroringNotification = @"UIApplicationDidDisableScreenMirroringNotification";

// Assuming CA loops at 60.0 fps (which is true on iPhone OS 3 : iPhone, iPad...)
#define CORE_ANIMATION_MAX_FRAMES_PER_SECOND (60)

UIImage* _UICreateScreenUIImage();

static CFTimeInterval startTime = 0;
static NSUInteger frames = 0;

@interface CSDisplayMirror(ScreenMirroringPrivate)

- (void) setupMirroringForScreen:(UIScreen *)anExternalScreen;
- (void) disableMirroringOnCurrentScreen;
- (void) updateMirroredScreenOnDisplayLink;

@end

@implementation CSDisplayMirror

static double targetFramesPerSecond = 0;
static CADisplayLink *displayLink = nil;
static UIScreen *mirroredScreen = nil;
static UIWindow *mirroredScreenWindow = nil;
static UIImageView *mirroredImageView = nil;

- (BOOL) isScreenMirroringActive
{
    return (displayLink && !displayLink.paused);
}

- (UIScreen *) currentMirroringScreen
{
    return mirroredScreen;
}

- (void) setupScreenMirroring
{
    [self setupScreenMirroringWithFramesPerSecond:ScreenMirroringDefaultFramesPerSecond];
}

- (void) setupScreenMirroringWithFramesPerSecond:(double)fps
{
    // Set the desired frame rate
    targetFramesPerSecond = fps;
    
    // Register for screen notifications
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(screenDidConnect:) name:UIScreenDidConnectNotification object:nil];
    [center addObserver:self selector:@selector(screenDidDisconnect:) name:UIScreenDidDisconnectNotification object:nil];
    [center addObserver:self selector:@selector(screenModeDidChange:) name:UIScreenModeDidChangeNotification object:nil];
    
    // Register for interface orientation changes (so we don't need to query on every frame refresh)
    [center addObserver:self selector:@selector(interfaceOrientationWillChange:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
    
    // Setup screen mirroring for an existing screen
    NSArray *connectedScreens = [UIScreen screens];
    if ([connectedScreens count] > 1) {
        UIScreen *mainScreen = [UIScreen mainScreen];
        for (UIScreen *aScreen in connectedScreens) {
            if (aScreen != mainScreen) {
                // We've found an external screen !
                [self setupMirroringForScreen:aScreen];
                break;
            }
        }
    }
}

- (void) disableScreenMirroring
{
    // Unregister from screen notifications
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:UIScreenDidConnectNotification object:nil];
    [center removeObserver:self name:UIScreenDidDisconnectNotification object:nil];
    [center removeObserver:self name:UIScreenModeDidChangeNotification object:nil];
    
    // Device orientation
    [center removeObserver:self name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
    
    // Remove mirroring
    [self disableMirroringOnCurrentScreen];
}

#pragma mark -
#pragma mark UIScreen notifications

- (void) screenDidConnect:(NSNotification *)aNotification
{
    NSLog(@"A new screen got connected: %@", [aNotification object]);
    [self setupMirroringForScreen:[aNotification object]];
}

- (void) screenDidDisconnect:(NSNotification *)aNotification
{
    NSLog(@"A screen got disconnected: %@", [aNotification object]);
    [self disableMirroringOnCurrentScreen];
}

- (void) screenModeDidChange:(NSNotification *)aNotification
{
    UIScreen *someScreen = [aNotification object];
    NSLog(@"The screen mode for a screen did change: %@", [someScreen currentMode]);
    
    // Disable, then reenable with new config
    [self disableMirroringOnCurrentScreen];
    [self setupMirroringForScreen:[aNotification object]];
}

#pragma mark -
#pragma mark Inteface orientation changes notification

- (void) updateMirroredWindowTransformForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Grab the secondary window layer
    CALayer *mirrorLayer = mirroredImageView.layer;
    
    // Rotate the screenshot to match interface orientation
    switch (interfaceOrientation) {
        case UIInterfaceOrientationPortrait:
            mirrorLayer.transform = CATransform3DIdentity;
            mirroredImageView.frame = mirroredScreenWindow.bounds;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            mirroredImageView.frame = CGRectMake(0,0,mirroredScreenWindow.bounds.size.height,mirroredScreenWindow.bounds.size.width);
            mirroredImageView.center = mirroredScreenWindow.center;
            mirrorLayer.transform = CATransform3DMakeRotation(M_PI / 2, 0.0f, 0.0f, 1.0f);
            break;
        case UIInterfaceOrientationLandscapeRight:
            mirroredImageView.frame = CGRectMake(0,0,mirroredScreenWindow.bounds.size.height,mirroredScreenWindow.bounds.size.width);
            mirroredImageView.center = mirroredScreenWindow.center;
            mirrorLayer.transform = CATransform3DMakeRotation(-(M_PI / 2), 0.0f, 0.0f, 1.0f);
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            mirrorLayer.transform = CATransform3DMakeRotation(M_PI, 0.0f, 0.0f, 1.0f);
            mirroredImageView.frame = mirroredScreenWindow.bounds;
            break;
        default:
            break;
    }
}

- (void) interfaceOrientationWillChange:(NSNotification *)aNotification
{
    NSDictionary *userInfo = [aNotification userInfo];
    UIInterfaceOrientation newInterfaceOrientation = (UIInterfaceOrientation) [[userInfo objectForKey:UIApplicationStatusBarOrientationUserInfoKey] unsignedIntegerValue];
    [self updateMirroredWindowTransformForInterfaceOrientation:newInterfaceOrientation];
}

#pragma mark -
#pragma mark Screen mirroring

- (void) setupMirroringForScreen:(UIScreen *)anExternalScreen
{
    // Reset timer
    startTime = CFAbsoluteTimeGetCurrent();
    frames = 0;
    
    // Set the new screen to mirror
    BOOL done = NO;
    UIScreenMode *mainScreenMode = [UIScreen mainScreen].currentMode;
    for (UIScreenMode *externalScreenMode in anExternalScreen.availableModes) {
        if (CGSizeEqualToSize(externalScreenMode.size, mainScreenMode.size)) {
            // Select a screen that matches the main screen
            anExternalScreen.currentMode = externalScreenMode;
            done = YES;
            break;
        }
    }
    
    if (!done && [anExternalScreen.availableModes count]) {
        anExternalScreen.currentMode = [anExternalScreen.availableModes objectAtIndex:0];
    }
    
    mirroredScreen = anExternalScreen;
    
    // Setup window in external screen
    UIWindow *newWindow = [[UIWindow alloc] initWithFrame:mirroredScreen.bounds];
    newWindow.opaque = YES;
    newWindow.hidden = NO;
    newWindow.backgroundColor = [UIColor blackColor];
    mirroredScreenWindow = newWindow;
    mirroredScreenWindow.screen = mirroredScreen;
    
    UIImageView *backgroundView = [[UIImageView alloc] initWithFrame:newWindow.bounds];
    [backgroundView setImage:[UIImage imageNamed:@"backgrounds/MountainLion"]];
    backgroundView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [newWindow addSubview:[backgroundView autorelease]];
    
    mirroredImageView = [[UIImageView alloc] initWithFrame:newWindow.bounds];
    mirroredImageView.contentMode = UIViewContentModeScaleAspectFit;
    [mirroredScreenWindow addSubview:mirroredImageView];
    
    // Apply transform on mirrored window to match device's interface orientation
    [self updateMirroredWindowTransformForInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation];
    
    // Setup periodic callbacks
    [displayLink invalidate];
    [displayLink release];
    displayLink = nil;
    
    // Setup display link sync
    displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateMirroredScreenOnDisplayLink)];
    [displayLink setFrameInterval:(targetFramesPerSecond >= CORE_ANIMATION_MAX_FRAMES_PER_SECOND) ? 1 : (CORE_ANIMATION_MAX_FRAMES_PER_SECOND / targetFramesPerSecond)];
    
    // We MUST add ourselves in the commons run loop in order to mirror during UITrackingRunLoopMode.
    // Otherwise, the display won't be updated while fingering are touching the screen.
    // This has a major impact on performance though...
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    
    // Post notification advertisting that we're setting up mirroring for the external screen
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidSetupScreenMirroringNotification object:anExternalScreen];
}

- (void) disableMirroringOnCurrentScreen
{
    // Post notification advertisting that we're tearing down mirroring
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidDisableScreenMirroringNotification object:mirroredScreen];
    
    [displayLink invalidate];
    [displayLink release];
    displayLink = nil;
    
    [mirroredScreen release];
    mirroredScreen = nil;
    [mirroredScreenWindow release];
    mirroredScreenWindow = nil;
    [mirroredImageView release];
    mirroredImageView = nil;
}

- (void) updateMirroredScreenOnDisplayLink
{
    @autoreleasepool {
        UIImage *mainWindowScreenshot = _UICreateScreenUIImage();
        mirroredImageView.image = mainWindowScreenshot;
        [mainWindowScreenshot release];
    }
}

@end