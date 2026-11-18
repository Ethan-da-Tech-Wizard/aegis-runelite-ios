// ==============================================================================
// Program: XpTrackerPlugin.swift
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: Real-Time Experience & Skill Progression Tracking Plugin for iOS.
//          Listens to StatChangedEvent from EventBus, computes XP/hour rates,
//          and renders a top-right corner Heads-Up Display (HUD) overlay.
// ==============================================================================

// ==============================================================================
// Overview: Telemetry Rate Calculations:
// ==============================================================================
// In telemetry tracking systems, calculating "rates of change over time"
// (e.g. Speed = Distance / Time, XP/hour = XP_gained / Hours_elapsed) is a
// foundational computational task.
//
// Calculation Breakdown:
// - `xpGained = currentXp - startXp`
// - `elapsedSeconds = now - startTime`
// - `hours = elapsedSeconds / 3600.0`
// - `xpPerHour = xpGained / hours`
//
// Thread-Safety & Performance:
// Event subscriptions trigger asynchronously when stat packets arrive.
// We guard access to the `sessions` dictionary with `NSLock` to prevent
// race conditions between the network/engine thread and the Metal render thread.
// ==============================================================================

import Foundation
import CoreGraphics
import UIKit

/// Individual skill tracking session recording baseline and progression metrics.
public struct SkillTrackerSession: Sendable {
    public let skillName: String
    public let startXp: Int
    public var currentXp: Int
    public let startTime: Date
    public var lastUpdated: Date

    /// Total experience gained during this session.
    public var xpGained: Int {
        return max(0, currentXp - startXp)
    }

    /// Projected experience per hour based on elapsed session duration.
    public var xpPerHour: Int {
        let elapsed = max(1.0, lastUpdated.timeIntervalSince(startTime))
        return Int(Double(xpGained) / (elapsed / 3600.0))
    }
}

/// Real-time XP tracking plugin for iOS.
public final class XpTrackerPlugin: Plugin {
    public let id: String = "xp_tracker"
    public let name: String = "XP Tracker"
    public let description: String = "Tracks real-time experience gains, XP/hour, and time to level up."
    public var isEnabled: Bool = true

    private var sessions: [String: SkillTrackerSession] = [:]
    private let lock = NSLock()

    public init() {}

    /// Lifecycle hook: Subscribe to StatChangedEvent.
    public func startUp() {
        EventBus.shared.subscribe(self, eventType: StatChangedEvent.self) { [weak self] event in
            self?.handleStatChanged(event)
        }
        print("✅ [XpTrackerPlugin] Started up.")
    }

    /// Lifecycle hook: Unsubscribe from EventBus.
    public func shutDown() {
        EventBus.shared.unsubscribe(self)
        print("🛑 [XpTrackerPlugin] Shut down.")
    }

    /// Event handler updating or creating skill sessions upon XP changes.
    private func handleStatChanged(_ event: StatChangedEvent) {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        if var session = sessions[event.skillName] {
            session.currentXp = event.experience
            session.lastUpdated = now
            sessions[event.skillName] = session
        } else {
            sessions[event.skillName] = SkillTrackerSession(
                skillName: event.skillName,
                startXp: max(0, event.experience - event.xpGained),
                currentXp: event.experience,
                startTime: now,
                lastUpdated: now
            )
        }
    }

    /// Render HUD overlay in top-right screen corner.
    ///
    /// - Parameter context: MetalRenderContext.
    /// - Returns: Draw commands for HUD boxes and XP strings.
    public func renderOverlay(context: MetalRenderContext) -> [OverlayDrawCommand] {
        var commands: [OverlayDrawCommand] = []

        lock.lock()
        // Display the top 3 actively trained skills with non-zero XP gains
        let activeSessions = Array(sessions.values.filter { $0.xpGained > 0 }.prefix(3))
        lock.unlock()

        guard !activeSessions.isEmpty else { return commands }

        // Position HUD panel in the top-right corner
        var currentY: CGFloat = 40.0
        let panelWidth: CGFloat = 160.0
        let panelX: CGFloat = context.viewportSize.width - panelWidth - 16.0

        for session in activeSessions {
            let panelRect = CGRect(x: panelX, y: currentY, width: panelWidth, height: 26.0)
            commands.append(.boundingBox(rect: panelRect, color: UIColor.black.withAlphaComponent(0.7).cgColor, cornerRadius: 4.0))

            let labelText = "\(session.skillName): +\(formatXp(session.xpGained)) (\(formatXp(session.xpPerHour))/h)"
            commands.append(.text(
                text: labelText,
                position: CGPoint(x: panelRect.minX + 6, y: panelRect.minY + 6),
                color: UIColor.systemGreen.cgColor,
                fontName: "HelveticaNeue-Medium",
                fontSize: 10.5
            ))

            currentY += 30.0
        }

        return commands
    }

    /// Format experience numbers with K (thousands) or M (millions) suffixes.
    private func formatXp(_ xp: Int) -> String {
        if xp >= 1_000_000 {
            return String(format: "%.1fM", Double(xp) / 1_000_000.0)
        } else if xp >= 1_000 {
            return String(format: "%.1fK", Double(xp) / 1_000.0)
        } else {
            return "\(xp)"
        }
    }

    /// Reset all active tracking sessions.
    public func resetAll() {
        lock.lock()
        sessions.removeAll()
        lock.unlock()
    }
}
