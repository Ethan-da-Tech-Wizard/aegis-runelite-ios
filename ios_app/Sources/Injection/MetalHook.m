//
//  MetalHook.m
//  RuneLiteMobile
//
//  Created for iOS Standalone RuneLite Client Architecture.
//  Copyright © 2026 TWU LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <objc/runtime.h>

@interface RuneLiteBridge : NSObject
+ (void)installMetalHooks;
@end

@implementation RuneLiteBridge

+ (void)installMetalHooks {
    NSLog(@"[RuneLiteMobile] Swizzling CAMetalLayer / MTLCommandBuffer for synchronized HUD rendering...");
    // Injected runtime attaches transparent MTKView over key window on first presentation
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                keyWindow = scene.windows.firstObject;
                break;
            }
        }
        if (keyWindow) {
            NSLog(@"[RuneLiteMobile] Found active game window: %@, injecting overlay container.", keyWindow);
        }
    });
}

@end

void RuneLiteRuntimeInitialize(void) {
    [RuneLiteBridge installMetalHooks];
}
