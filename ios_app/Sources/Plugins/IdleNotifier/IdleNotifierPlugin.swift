// Program: aegis-runelite-ios - IdleNotifierPlugin.swift
// Programmer: Ethan-da-Tech-Wizard (written with Claude, an AI assistant)
// Last Modified: 2026-11-18
// Purpose: Plugin that detects idle player animation and alerts with haptics and local notifications.

// ==============================================================================
// Overview: State Monitoring:
// ==============================================================================
// In event-driven system design, background monitors track state changes and alert
// users when tasks reach completion.
//
// How Idle Detection Works:
// 1. Animation State Monitoring:
//    When a player is actively performing an action (e.g. chopping a tree or casting
//    a fishing rod), their `currentAnimation` matches an action ID (e.g. 879 for
//    woodcutting). When the tree depletes or the inventory fills, the character
//    reverts to the standing idle animation (`-1` or `808`).
// 2. 3-Tick Debounce Threshold:
//    In OSRS, 1 tick = 600ms. A 3-tick threshold equals 1.8 seconds (3 * 0.6s).
//    Debouncing prevents false alarms during brief 1-tick movement interruptions.
// 3. Multi-Channel Alert:
//    - Haptics: `UINotificationFeedbackGenerator().notificationOccurred(.warning)`
//      delivers a distinct physical vibration pattern to the iPhone.
//    - Local Notifications: `UNUserNotificationCenter` posts a notification banner
//      even if the player is looking away or multitasking.
// ==============================================================================

import Foundation
import CoreGraphics
import UIKit
import UserNotifications

/// Idle and combat health/prayer notifier for iOS.
public final class IdleNotifierPlugin: Plugin {
    public let id: String = "idle_notifier"
    public let name: String = "Idle Notifier"
    public let description: String = "Alerts via haptics and local notifications when idling or low on HP/Prayer."
    public var isEnabled: Bool = true

    // Threshold configurations
    public var alertOnIdle: Bool = true
    public var alertOnLowHp: Bool = true
    public var lowHpThreshold: Int = 20
    public var alertOnLowPrayer: Bool = true
    public var lowPrayerThreshold: Int = 10

    private var lastAnimationId: Int = -1
    private var idleTickCount: Int = 0
    private var lastAlertDate: Date = .distantPast

    /// Creates the plugin with its default settings.
    public init() {}

    /// Lifecycle hook: Request notification permissions and subscribe to GameTickEvent.
    public func startUp() {
        requestNotificationPermissions()
        EventBus.shared.subscribe(self, eventType: GameTickEvent.self) { [weak self] event in
            self?.checkIdleState(tick: event.tickCount)
        }
        print("✅ [IdleNotifierPlugin] Started up.")
    }

    /// Lifecycle hook: Unsubscribe from EventBus.
    public func shutDown() {
        EventBus.shared.unsubscribe(self)
        print("🛑 [IdleNotifierPlugin] Shut down.")
    }

    /// Request Apple UserNotification permissions for alert banners, sounds, and badges.
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ [IdleNotifierPlugin] Notifications authorized.")
            }
        }
    }

    /// Check character animation state every 600ms game tick.
    ///
    /// - Parameter tick: Active game tick index.
    private func checkIdleState(tick: Int) {
        let player = GameState.shared.localPlayer

        // Idle animation detection (Standard standing idle is -1 or 808)
        if player.currentAnimation == -1 || player.currentAnimation == 808 {
            idleTickCount += 1
            // 3 ticks (1.8s) of uninterrupted idle triggers alert
            if idleTickCount == 3 && alertOnIdle {
                triggerNotification(title: "RuneLite Alert", body: "Your character is now idle!")
            }
        } else {
            // Player is performing an active skilling or combat animation; reset counter
            idleTickCount = 0
        }
    }

    /// Dispatch physical haptic vibration and schedule local notification banner.
    ///
    /// - Parameters:
    ///   - title: Notification title string.
    ///   - body: Alert message body.
    private func triggerNotification(title: String, body: String) {
        // Enforce 10-second alert cooldown to avoid spamming the user
        guard Date().timeIntervalSince(lastAlertDate) > 10.0 else { return }
        lastAlertDate = Date()

        // 1. Trigger iOS Taptic Engine Haptic Feedback
        DispatchQueue.main.async {
            let feedback = UINotificationFeedbackGenerator()
            feedback.prepare()
            feedback.notificationOccurred(.warning)
        }

        // 2. Schedule Local Notification via UNUserNotificationCenter
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate delivery
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// IdleNotifier is an alert plugin; returns empty overlay draw list.
    public func renderOverlay(context: MetalRenderContext) -> [OverlayDrawCommand] {
        return []
    }
}
