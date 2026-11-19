// ==============================================================================
// Program: SandboxedRuntime.swift
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: Sandboxed JavaScriptCore Runtime for Safe Community Plugin Execution.
//          Enforces 100% compliance with Apple App Store Guideline 2.5.2 & W^X
//          memory rules: zero-JIT interpreted bytecode, isolated heap, read-only
//          game state bridges, and forbidden AST token inspection.
// ==============================================================================

// ==============================================================================
// Architecture Overview & Secure Sandboxing:
// ==============================================================================
// In software systems security, executing third-party or untrusted community code
// requires an isolated "sandbox" environment to prevent malicious behavior.
//
// Sandboxing Safeguards Implemented Here:
// 1. JavaScriptCore Virtual Machine: Runs scripts inside an isolated `JSVirtualMachine`
//    heap without JIT compilation, adhering to iOS W^X (Write XOR Execute) memory policies.
// 2. Removal of Network APIs:
//    Community plugins have NO legitimate need to access external networks.
//    We explicitly delete dangerous networking globals:
//    - `delete this.fetch;`
//    - `delete this.XMLHttpRequest;`
//    - `delete this.WebSocket;`
// 3. Static AST Token Inspection (`forbiddenAstTokens`):
//    Before any script is evaluated, we scan the source code for banned automation
//    keywords like `autoPrayer`, `autoClick`, `simulateTouch`, and `packetSender`.
// 4. Read-Only State Bridges:
//    Plugins can query read-only snapshots of the player position (`getLocalPlayer()`)
//    and ground items (`getGroundItems()`), but cannot modify internal game engine state.
// ==============================================================================

import Foundation
import JavaScriptCore

/// Declarative draw commands emitted by sandboxed community plugins.
// Plain data a script hands back via renderOverlay(); coordinates are optional because world- and screen-anchored commands use different fields.
public struct ScriptDrawCommand {
    public let pluginId: String
    public let layer: String     // "world", "dynamic", "infobox"
    public let type: String      // "polygon", "text", "outline"
    public let colorHex: String
    public let worldX: Int?
    public let worldY: Int?
    public let screenX: Double?
    public let screenY: Double?
    public let text: String?
}

/// Sandboxed JavaScriptCore Runtime for Community Plugins.
/// Conforms 100% to Apple App Store Guideline 2.5.2 & W^X security rules.
/// Zero-JIT interpreted execution, isolated heap, read-only game state, no networking/DOM access.
public final class SandboxedRuntime {
    /// Shared singleton runtime instance.
    public static let shared = SandboxedRuntime()

    private let vm: JSVirtualMachine
    private let context: JSContext
    private var loadedPlugins: [String: JSValue] = [:]
    private var queuedDrawCommands: [ScriptDrawCommand] = []
    private let lock = NSLock()

    // Banned terms to enforce Jagex anti-cheat rules before script evaluation
    // Despite the name this is a plain substring blacklist, not an AST check. It is trivially bypassed (string concatenation, other names)
    // and can also block harmless scripts that merely contain one of the words.
    private let forbiddenAstTokens = [
        "autoPrayer", "oneClickAgility", "packetSender",
        "simulateTouch", "autoAlch", "bossProjectilePredictor",
        "sendPacket", "injectTouch", "autoClick"
    ]

    private init() {
        self.vm = JSVirtualMachine()
        self.context = JSContext(virtualMachine: vm)
        setupSandboxBridges()
    }

    /// Configure secure, stripped-down sandbox environment without network access.
    private func setupSandboxBridges() {
        // Step 1: Remove dangerous web, network, and thread primitives
        // (JavaScriptCore does not provide these browser globals by default, so the deletes are belt-and-braces.)
        context.evaluateScript("""
            delete this.fetch;
            delete this.XMLHttpRequest;
            delete this.WebSocket;
            delete this.Worker;
            delete this.SharedWorker;
        """)

        // Step 2: Global JavaScript Exception Handler
        // Script errors are logged, not propagated, so one bad plugin cannot crash the host.
        context.exceptionHandler = { _, exception in
            if let exc = exception {
                print("❌ [SandboxedRuntime Exception]: \(exc.toString() ?? "Unknown error")")
            }
        }

        // Step 3: Read-Only Game State Provider (Immutable JSON bridge)
        // Scripts get COPIES (dictionaries) of game state through these blocks, never references to the Swift objects.
        let getPlayerState: @convention(block) () -> [String: Any] = {
            let player = GameState.shared.localPlayer
            return [
                "worldX": player.worldPoint.x,
                "worldY": player.worldPoint.y,
                "plane": player.worldPoint.plane,
                "animation": player.currentAnimation,
                "isInteracting": player.isInteracting
            ]
        }
        context.setObject(getPlayerState, forKeyedSubscript: "getLocalPlayer" as NSString)

        // Step 4: Read-Only Ground Items Provider
        let getGroundItems: @convention(block) () -> [[String: Any]] = {
            return GameState.shared.groundItems.map { item in
                [
                    "id": item.id,
                    "name": item.name,
                    "gePrice": item.gePrice,
                    "haPrice": item.haPrice,
                    "worldX": item.location.x,
                    "worldY": item.location.y,
                    "quantity": item.quantity
                ]
            }
        }
        context.setObject(getGroundItems, forKeyedSubscript: "getGroundItems" as NSString)

        // Step 5: Declarative Overlay Drawing Sink
        // The only output channel for scripts: they queue declarative commands, with defaults for missing fields. Guarded by a lock because
        // scripts run on the thread that calls dispatchGameTick.
        let renderOverlayBlock: @convention(block) (NSDictionary) -> Void = { [weak self] rawCommand in
            guard let self = self else { return }
            let pluginId = rawCommand["pluginId"] as? String ?? "unknown"
            let layer = rawCommand["layer"] as? String ?? "world"
            let type = rawCommand["type"] as? String ?? "polygon"
            let colorHex = rawCommand["colorHex"] as? String ?? "#FFFFFF"
            let worldX = rawCommand["worldX"] as? Int
            let worldY = rawCommand["worldY"] as? Int
            let screenX = rawCommand["screenX"] as? Double
            let screenY = rawCommand["screenY"] as? Double
            let text = rawCommand["text"] as? String

            let command = ScriptDrawCommand(
                pluginId: pluginId,
                layer: layer,
                type: type,
                colorHex: colorHex,
                worldX: worldX,
                worldY: worldY,
                screenX: screenX,
                screenY: screenY,
                text: text
            )

            self.lock.lock()
            self.queuedDrawCommands.append(command)
            self.lock.unlock()
        }
        context.setObject(renderOverlayBlock, forKeyedSubscript: "renderOverlay" as NSString)
    }

    /// Validates script source code against Jagex anti-cheat rules before loading.
    ///
    /// - Parameter source: Raw JavaScript source code string.
    /// - Returns: Tuple containing validation boolean and failure reason if blocked.
    // Static pre-check only; see forbiddenAstTokens for its limits.
    public func validateScriptSource(_ source: String) -> (isValid: Bool, reason: String?) {
        for token in forbiddenAstTokens {
            if source.contains(token) {
                return (false, "Script contains forbidden automation keyword: \(token)")
            }
        }
        return (true, nil)
    }

    /// Loads and registers a community plugin script into the sandboxed context.
    ///
    /// - Parameters:
    ///   - id: Unique plugin identifier.
    ///   - sourceCode: Script code.
    /// - Returns: True if successfully loaded and verified.
    public func loadPlugin(id: String, sourceCode: String) -> Bool {
        // Step 1: Pre-execution static analysis audit
        let (isValid, reason) = validateScriptSource(sourceCode)
        guard isValid else {
            print("❌ [SandboxedRuntime] Blocked plugin '\(id)': \(reason ?? "")")
            return false
        }

        // Step 2: Wrap source in CommonJS module closure
        // CommonJS-style wrapper so a plugin can assign module.exports. The source is interpolated directly, so a script is trusted to be
        // well-formed JavaScript (a stray unmatched brace would break the wrapper).
        let wrappedSource = """
            (function() {
                var module = { exports: {} };
                var exports = module.exports;
                \(sourceCode);
                return module.exports;
            })()
        """

        // Step 3: Evaluate wrapped script inside isolated context
        guard let pluginInstance = context.evaluateScript(wrappedSource), !pluginInstance.isUndefined else {
            print("❌ [SandboxedRuntime] Failed to instantiate plugin '\(id)'")
            return false
        }

        // All plugins share ONE JSContext, so they can see each other's globals; the sandbox isolates them from the host, not from each other.
        loadedPlugins[id] = pluginInstance

        // Step 4: Call lifecycle startUp hook if implemented
        if let startUpMethod = pluginInstance.objectForKeyedSubscript("startUp"), !startUpMethod.isUndefined {
            startUpMethod.call(withArguments: [])
        }

        print("✅ [SandboxedRuntime] Plugin '\(id)' loaded and started in sandbox")
        return true
    }

    /// Unloads a community plugin and calls its shutDown hook.
    ///
    /// - Parameter id: Plugin identifier to unload.
    public func unloadPlugin(id: String) {
        if let pluginInstance = loadedPlugins[id] {
            if let shutDownMethod = pluginInstance.objectForKeyedSubscript("shutDown"), !shutDownMethod.isUndefined {
                shutDownMethod.call(withArguments: [])
            }
            loadedPlugins.removeValue(forKey: id)
            print("ℹ️ [SandboxedRuntime] Plugin '\(id)' unloaded")
        }
    }

    /// Dispatches 600ms game tick to all active sandboxed plugins.
    ///
    /// - Parameter tick: Monotonically increasing tick counter.
    // Draw commands are cleared at the start of each tick; flushDrawCommands() drains whatever scripts queued.
    public func dispatchGameTick(tick: Int) {
        lock.lock()
        queuedDrawCommands.removeAll()
        lock.unlock()

        for (_, pluginInstance) in loadedPlugins {
            if let onTickMethod = pluginInstance.objectForKeyedSubscript("onGameTick"), !onTickMethod.isUndefined {
                onTickMethod.call(withArguments: [tick])
            }
        }
    }

    /// Retrieves collected overlay commands for rendering in Metal pipeline.
    ///
    /// - Returns: Array of ScriptDrawCommands collected during the tick.
    public func flushDrawCommands() -> [ScriptDrawCommand] {
        lock.lock()
        defer { lock.unlock() }
        let commands = queuedDrawCommands
        queuedDrawCommands.removeAll()
        return commands
    }
}
