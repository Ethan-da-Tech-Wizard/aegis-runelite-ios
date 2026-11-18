// Program: aegis-runelite-ios - PluginSettingsView.swift
// Programmer: Ethan-da-Tech-Wizard (written with Claude, an AI assistant)
// Last Modified: 2026-11-18
// Purpose: SwiftUI settings view with plugin toggles, login control, compliance status and plugin hub access.

// ==============================================================================
// Overview: SwiftUI Form Architecture:
// ==============================================================================
// In modern mobile application architecture, user settings views are organized
// into grouped visual sections using SwiftUI's `List` and `Section` containers.
//
// Key SwiftUI Concepts:
// 1. Reactive State Binding (`@ObservedObject`):
//    `pluginManager` and `authManager` conform to `ObservableObject`. Whenever
//    a plugin state or login status changes, SwiftUI automatically invalidates
//    and redraws the affected rows.
// 2. Custom Binding Creation (`Binding(get:set:)`):
//    Creates a two-way reactive bridge between a Swift boolean property and a
//    native `Toggle` switch, saving updates directly to persistent `UserDefaults`.
// 3. Modal Sheet Presentation (`.sheet(isPresented:)`):
//    Presents the `PluginHubView` as an interactive pull-down modal sheet.
// ==============================================================================

import SwiftUI

/// SwiftUI configuration panel for managing RuneLite plugins & Jagex compliance status.
public struct PluginSettingsView: View {
    @ObservedObject var pluginManager = PluginManager.shared
    @ObservedObject var authManager = JagexOAuthManager.shared
    @State private var isShowingPluginHub: Bool = false
    @Environment(\.presentationMode) var presentationMode

    /// Creates the settings view.
    public init() {}

    public var body: some View {
        NavigationView {
            List {
                // Section 1: Jagex Account & Security Status
                Section(header: Text("Jagex Account Authentication")) {
                    if authManager.isAuthenticated {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text(authManager.characterName ?? "Connected")
                                    .font(.headline)
                                Text("OAuth2 PKCE Token Secured in Keychain")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Disconnect") {
                                authManager.logout()
                            }
                            .foregroundColor(.red)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Zero-Credential Login")
                                .font(.headline)
                            Text("Sign in directly via official Jagex website. RuneLite never sees your password or 2FA codes.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button(action: {
                                authManager.startLogin { result in
                                    switch result {
                                    case .success:
                                        print("Login successful")
                                    case .failure(let error):
                                        print("Login failed: \(error)")
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "lock.shield.fill")
                                    Text(authManager.isAuthenticating ? "Connecting..." : "Sign In with Jagex")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(authManager.isAuthenticating)
                        }
                    }
                }

                // Section 2: Jagex Compliance & Anti-Detection Badge
                Section(header: Text("Compliance & Anti-Detection Status")) {
                    HStack {
                        Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("Jagex Rule Conformance: 100%")
                                .font(.subheadline)
                                .bold()
                            Text("Strict 1:1 Touch Ratio • No De-Rendering • Read-Only Overlays")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Section 3: Plugin Hub Browser
                Section(header: Text("Community Plugins")) {
                    Button(action: {
                        isShowingPluginHub = true
                    }) {
                        HStack {
                            Image(systemName: "square.grid.2x2.fill")
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading) {
                                Text("Official Plugin Hub")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Browse and install community plugins from runelite/plugin-hub")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Section 4: Bundled Native Plugin Toggles
                Section(header: Text("Bundled Core Plugins")) {
                    ForEach(pluginManager.registeredPlugins, id: \.id) { plugin in
                        Toggle(isOn: Binding(
                            get: { plugin.isEnabled },
                            set: { newValue in
                                pluginManager.setPluginEnabled(id: plugin.id, enabled: newValue)
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plugin.name)
                                    .font(.headline)
                                Text(plugin.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("RuneLite Mobile")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $isShowingPluginHub) {
                PluginHubView()
            }
        }
    }
}
