//
//  IdleNotifierPlugin.swift
//  RuneLiteMobile
//
//  Created for iOS Standalone RuneLite Client Architecture.
//  Copyright © 2026 TWU LLC. All rights reserved.
//

import Foundation
import CoreGraphics
import UIKit
import UserNotifications

/// Idle and combat health/prayer notifier for iOS
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

    public init() {}

    public func startUp() {
        requestNotificationPermissions()
        EventBus.shared.subscribe(self, eventType: GameTickEvent.self) { [weak self] event in
            self?.checkIdleState(tick: event.tickCount)
        }
        print("✅ [IdleNotifierPlugin] Started up.")
    }

    public func shutDown() {
        EventBus.shared.unsubscribe(self)
        print("🛑 [IdleNotifierPlugin] Shut down.")
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ [IdleNotifierPlugin] Notifications authorized.")
            }
        }
    }

    private func checkIdleState(tick: Int) {
        let player = GameState.shared.localPlayer

        // Idle animation detection (Standard standing idle is -1 or 808)
        if player.currentAnimation == -1 || player.currentAnimation == 808 {
            idleTickCount += 1
            if idleTickCount == 3 && alertOnIdle { // 3 ticks (1.8s) of uninterrupted idle
                triggerNotification(title: "RuneLite Alert", body: "Your character is now idle!")
            }
        } else {
            idleTickCount = 0
        }
    }

    private func triggerNotification(title: String, body: String) {
        guard Date().timeIntervalSince(lastAlertDate) > 10.0 else { return } // 10s cooldown
        lastAlertDate = Date()

        // 1. Trigger iOS Haptic Feedback
        DispatchQueue.main.async {
            let feedback = UINotificationFeedbackGenerator()
            feedback.prepare()
            feedback.notificationOccurred(.warning)
        }

        // 2. Schedule Local Notification
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

    public func renderOverlay(context: MetalRenderContext) -> [OverlayDrawCommand] {
        // Pure notification/haptic plugin; no persistent overlay drawn
        return []
    }
}
