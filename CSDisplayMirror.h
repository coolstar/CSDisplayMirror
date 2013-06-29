//
//  CSDisplayMirror.h
//  CSDisplayMirror
//
//  Created by CoolStar on 6/29/13.
//  Copyright (c) 2013 CoolStar. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString * const UIApplicationDidSetupScreenMirroringNotification;
extern NSString * const UIApplicationDidDisableScreenMirroringNotification;

static const NSUInteger ScreenMirroringDefaultFramesPerSecond = 15;

@interface CSDisplayMirror : NSObject

- (BOOL) isScreenMirroringActive;
- (UIScreen *) currentMirroringScreen;
- (void) setupScreenMirroring;
- (void) setupScreenMirroringWithFramesPerSecond:(double)fps;
- (void) disableScreenMirroring;

@end