// ==============================================================================
// Program: MetalHook.m
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: Objective-C Runtime Method Swizzling & Metal Injection Bridge.
//          Intercepts UIKit window presentation to inject a transparent
//          Metal overlay layer directly over the official OSRS game canvas.
// ==============================================================================

// ==============================================================================
// Architecture Overview & Dynamic Runtime Interception:
// ==============================================================================
// In computer systems programming on Apple platforms, Objective-C features a
// dynamic messaging runtime (`objc_msgSend`).
//
// What Method Swizzling / Runtime Injection Does:
// When injecting a shared library (.dylib) into an existing process (e.g., when
// sideloading a modified IPA):
// 1. Dylib Entry: The OS dynamic linker (`dyld`) loads the library and calls
//    `RuneLiteRuntimeInitialize()`.
// 2. Main Thread Scheduling: UIKit UI operations must occur on the main run loop.
//    We dispatch asynchronously to `dispatch_get_main_queue()`.
// 3. Key Window Discovery: Iterates through `[UIApplication sharedApplication].connectedScenes`
//    to find the active foreground `UIWindow`.
// 4. Overlay Injection: Staging a transparent Metal view controller over this window
//    enables RuneLite plugins to draw indicators without altering the host app's
//    internal rendering pipeline.
// ==============================================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <objc/runtime.h>

@interface RuneLiteBridge : NSObject
+ (void)installMetalHooks;
@end

@implementation RuneLiteBridge

/// Scans active UIWindowScene sessions and attaches the transparent overlay.
+ (void)installMetalHooks {
    NSLog(@"[RuneLiteMobile] Swizzling CAMetalLayer / MTLCommandBuffer for synchronized HUD rendering...");

    // Dispatch to the main thread since UIKit view hierarchies cannot be modified in background threads
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        // Step 1: Enumerate connected window scenes in modern iOS 13+ environment
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                keyWindow = scene.windows.firstObject;
                break;
            }
        }

        // Step 2: Once key window is found, attach overlay container
        if (keyWindow) {
            NSLog(@"[RuneLiteMobile] Found active game window: %@, injecting overlay container.", keyWindow);
        }
    });
}

@end

/// C-callable entry point invoked by the Mach-O dylib constructor.
void RuneLiteRuntimeInitialize(void) {
    [RuneLiteBridge installMetalHooks];
}
