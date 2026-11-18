//
//  DylibEntry.c
//  RuneLiteMobile
//
//  Created for iOS Standalone RuneLite Client Architecture.
//  Copyright © 2026 TWU LLC. All rights reserved.
//

#include <stdio.h>
#include <stdbool.h>

// Forward declaration of Objective-C runtime initializer
extern void RuneLiteRuntimeInitialize(void);

// Mach-O library constructor: executed automatically upon dlopen / dyld load
__attribute__((constructor))
static void RuneLiteDylibConstructor(void) {
    printf("[RuneLiteMobile] Dynamic library successfully injected into OSRS process.\n");
    printf("[RuneLiteMobile] Initializing RuneLite Swift Core & Metal hooks...\n");
    
    // Call into Objective-C / Swift runtime hook
    RuneLiteRuntimeInitialize();
}

__attribute__((destructor))
static void RuneLiteDylibDestructor(void) {
    printf("[RuneLiteMobile] Dynamic library unloading...\n");
}
