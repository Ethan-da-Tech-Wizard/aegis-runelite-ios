// ==============================================================================
// Program: PluginManager.swift
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: Central Plugin Registry and Lifecycle Controller for RuneLite Mobile iOS.
//          Manages registration, persistent enabled/disabled states via UserDefaults,
//          startup/shutdown lifecycle transitions, and collection of Metal overlay
//          draw commands from active plugins.
// ==============================================================================

// ==============================================================================
// Overview: Plugin Architecture:
// ==============================================================================
// In extensible software design, an application core should be open for extension
// but closed for modification (the Open-Closed Principle).
//
// Plugin Architecture Principles:
// 1. Uniform Interface: All plugins implement `PluginProtocol` (`startUp`, `shutDown`,
//    `renderOverlay`).
// 2. Dynamic Lifecycle: Users can enable or disable plugins in real time without
//    restarting the client.
// 3. Command Aggregation: Every frame, `collectDrawCommands()` polls each enabled
//    plugin for its visual draw primitives (quads, text labels, outlines) and
//    assembles them into a single list for GPU rendering in Metal.
// ==============================================================================

import Foundation
import Combine

/// Central registry and lifecycle controller for all RuneLite plugins.
public final class PluginManager: ObservableObject {
    /// Shared singleton instance.
    public static let shared = PluginManager()

    /// Array of all registered plugins currently loaded in memory.
    @Published public private(set) var registeredPlugins: [Plugin] = []
    private var pluginMap: [String: Plugin] = [:]
    private let userDefaults = UserDefaults.standard

    private init() {}

    /// Register a new plugin into the engine and start it up if enabled.
    ///
    /// - Parameter plugin: The plugin instance conforming to PluginProtocol.
    public func register(plugin: Plugin) {
        registeredPlugins.append(plugin)
        pluginMap[plugin.id] = plugin

        // Load saved enabled state from persistent storage (defaults to enabled)
        let savedState = userDefaults.object(forKey: "plugin_enabled_\(plugin.id)") as? Bool ?? true
        plugin.isEnabled = savedState

        // If enabled, invoke lifecycle startup hook
        if plugin.isEnabled {
            plugin.startUp()
        }
    }

    /// Toggle a plugin on or off by its unique identifier.
    ///
    /// - Parameters:
    ///   - id: Plugin identifier string (e.g. "tile_indicators").
    ///   - enabled: Boolean target state.
    public func setPluginEnabled(id: String, enabled: Bool) {
        guard let plugin = pluginMap[id] else { return }
        if plugin.isEnabled != enabled {
            plugin.isEnabled = enabled
            // Persist preference to UserDefaults
            userDefaults.set(enabled, forKey: "plugin_enabled_\(id)")

            // Invoke appropriate lifecycle transition
            if enabled {
                plugin.startUp()
            } else {
                plugin.shutDown()
            }
            // Trigger SwiftUI reactive UI redraws
            objectWillChange.send()
        }
    }

    /// Retrieve all active draw commands from enabled plugins for the current frame.
    ///
    /// - Parameter context: The MetalRenderContext containing camera and viewport parameters.
    /// - Returns: Consolidated array of OverlayDrawCommands to be rendered by Metal.
    public func collectDrawCommands(context: MetalRenderContext) -> [OverlayDrawCommand] {
        var allCommands: [OverlayDrawCommand] = []
        for plugin in registeredPlugins where plugin.isEnabled {
            let commands = plugin.renderOverlay(context: context)
            allCommands.append(contentsOf: commands)
        }
        return allCommands
    }

    /// Find a plugin by its concrete Swift type.
    ///
    /// - Parameter type: The expected Plugin class type.
    /// - Returns: Casted plugin instance or nil.
    public func getPlugin<T: Plugin>(type: T.Type) -> T? {
        return registeredPlugins.first { $0 is T } as? T
    }
}
