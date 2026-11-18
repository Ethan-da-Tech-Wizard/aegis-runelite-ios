// ==============================================================================
// Program: DylibEntry.c
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: Mach-O Dynamic Library Constructor & Destructor Lifecycle Hooks.
//          Executes automatically when the injected RuneLiteOverlay.dylib is
//          mapped into the OSRS process address space by Apple's dynamic linker (dyld).
// ==============================================================================

// ==============================================================================
// Architecture Overview & Dynamic Linker Lifecycle:
// ==============================================================================
// In low-level systems programming (C and operating systems), compiled dynamic
// shared libraries (.dylib on macOS/iOS, .so on Linux, .dll on Windows) can define
// special initialization functions that run BEFORE `main()`.
//
// Compiler Attributes:
// 1. `__attribute__((constructor))`:
//    Tells the Clang/GCC compiler to place a function pointer into the Mach-O binary's
//    `__mod_init_func` section. When `dyld` (the dynamic linker) maps the library into
//    virtual memory, it automatically calls every constructor function in this table.
// 2. `__attribute__((destructor))`:
//    Places function pointers into `__mod_term_func`. Called when the process exits
//    or when `dlclose()` unloads the library.
// ==============================================================================

#include <stdio.h>
#include <stdbool.h>

// Forward declaration of Objective-C runtime initializer defined in MetalHook.m
extern void RuneLiteRuntimeInitialize(void);

/// Mach-O library constructor: executed automatically upon dlopen / dyld load.
__attribute__((constructor))
static void RuneLiteDylibConstructor(void) {
    // Step 1: Log library injection confirmation to stdout / system log
    printf("[RuneLiteMobile] Dynamic library successfully injected into OSRS process.\n");
    printf("[RuneLiteMobile] Initializing RuneLite Swift Core & Metal hooks...\n");

    // Step 2: Call into Objective-C / Swift runtime hook to install overlay views
    RuneLiteRuntimeInitialize();
}

/// Mach-O library destructor: executed automatically when the library unloads.
__attribute__((destructor))
static void RuneLiteDylibDestructor(void) {
    printf("[RuneLiteMobile] Dynamic library unloading...\n");
}
