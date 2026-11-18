//
//  PluginManager.swift
//  RuneLiteMobile
//
//  Created for iOS Standalone RuneLite Client Architecture.
//  Copyright © 2026 TWU LLC. All rights reserved.
//

import Foundation
import Combine

/// Central registry and lifecycle controller for all RuneLite plugins
public final class PluginManager: ObservableObject {
    public static let shared = PluginManager()

    @Published public private(set) var registeredPlugins: [Plugin] = []
    private var pluginMap: [String: Plugin] = [:]
    private let userDefaults = UserDefaults.standard

    private init() {}

    /// Register a plugin into the engine
    public func register(plugin: Plugin) {
        registeredPlugins.append(plugin)
        pluginMap[plugin.id] = plugin

        // Load saved enabled state
        let savedState = userDefaults.object(forKey: "plugin_enabled_\(plugin.id)") as? Bool ?? true
        plugin.isEnabled = savedState

        if plugin.isEnabled {
            plugin.startUp()
        }
    }

    /// Toggle plugin state
    public func setPluginEnabled(id: String, enabled: Bool) {
        guard let plugin = pluginMap[id] else { return }
        if plugin.isEnabled != enabled {
            plugin.isEnabled = enabled
            userDefaults.set(enabled, forKey: "plugin_enabled_\(id)")

            if enabled {
                plugin.startUp()
            } else {
                plugin.shutDown()
            }
            objectWillChange.send()
        }
    }

    /// Retrieve all active draw commands from enabled plugins
    public func collectDrawCommands(context: MetalRenderContext) -> [OverlayDrawCommand] {
        var allCommands: [OverlayDrawCommand] = []
        for plugin in registeredPlugins where plugin.isEnabled {
            let commands = plugin.renderOverlay(context: context)
            allCommands.append(contentsOf: commands)
        }
        return allCommands
    }

    /// Find a plugin by type
    public func getPlugin<T: Plugin>(type: T.Type) -> T? {
        return registeredPlugins.first { $0 is T } as? T
    }
}
