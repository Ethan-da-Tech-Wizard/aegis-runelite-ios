// ==============================================================================
// Program: PluginHubView.swift
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: In-App RuneLite Plugin Hub Browser & Package Manager for iOS.
//          Allows players to search, filter by category tags, install, toggle,
//          and remove verified community plugins (Loot Tracker, Quest Helper).
// ==============================================================================

// ==============================================================================
// Architecture Overview & Filtered List Architectures:
// ==============================================================================
// In user interface development, providing fluid search and category filtering
// over structured data collections is a standard programming requirement.
//
// Key Concepts:
// 1. Dynamic Filtering Computations (`filteredPlugins`):
//    A computed property applies two sequential predicate filters:
//    - Category Filter: Checks if `selectedFilter == "All"` or `plugin.tags.contains(selectedFilter)`.
//    - Substring Text Search: Matches `searchText` against plugin `displayName`,
//      `summary`, and `author` using case-insensitive localization matching.
// 2. State-Driven UI Controls:
//    - Category horizontal scroll pill buttons update `selectedFilter`.
//    - `Toggle` buttons trigger `hubClient.togglePlugin`.
//    - "Install" buttons trigger `hubClient.installPlugin(manifest:)`.
//    - Trash icons trigger `hubClient.uninstallPlugin(id:)`.
// ==============================================================================

import SwiftUI

/// Authentic in-app RuneLite Plugin Hub browser for iOS.
/// Allows players to search, install, toggle, and manage official community plugins.
public struct PluginHubView: View {
    // Shared client singleton; installs, removals and toggles made anywhere in the app refresh this list automatically.
    @ObservedObject var hubClient = PluginHubClient.shared

    // searchText and selectedFilter are local view state: they are not saved, so the browser opens unfiltered each time.
    @State private var searchText: String = ""
    @State private var selectedFilter: String = "All"
    @Environment(\.presentationMode) var presentationMode

    // Filter chips; 'All' plus tag names used in the sample catalog.
    // Must match the tag strings in the catalog entries (HubPluginManifest.tags), because the filter compares them exactly and case-sensitively.
    private let categories = ["All", "pvm", "skilling", "utility", "quests", "combat"]

    public init() {}

    /// Computed property returning filtered plugins matching both category and search query.
    // Case-insensitive search over name/summary/author combined (AND) with the selected tag chip.
    public var filteredPlugins: [HubPluginManifest] {
        hubClient.availablePlugins.filter { plugin in

            // The two predicates are combined with AND, so a search only looks inside the selected category.
            let matchesCategory = selectedFilter == "All" || plugin.tags.contains(selectedFilter)
            let matchesSearch = searchText.isEmpty ||
                plugin.displayName.localizedCaseInsensitiveContains(searchText) ||
                plugin.summary.localizedCaseInsensitiveContains(searchText) ||
                plugin.author.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category Filter Pills (Horizontal Scroll Bar)
                // Horizontal scroll so six pills fit on a narrow phone without wrapping.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { category in
                            Button(action: { selectedFilter = category }) {
                                Text(category.capitalized)
                                    .font(.subheadline)
                                    .fontWeight(selectedFilter == category ? .bold : .regular)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(selectedFilter == category ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                                    .foregroundColor(selectedFilter == category ? .white : .primary)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                Divider()

                // Filtered Plugin List
                // The header count uses filteredPlugins.count so the user sees how many results the current search and category produce.
                List {
                    Section(header: Text("Official RuneLite Plugin Hub (\(filteredPlugins.count) Available)")) {
                        ForEach(filteredPlugins) { plugin in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(plugin.displayName)
                                            .font(.headline)
                                        Text("by \(plugin.author) • v\(plugin.version)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()

                                    // An installed plugin shows an enable switch and a trash button; a not-installed one shows Install. The two states never appear together.
                                    if plugin.isInstalled {
                                        HStack(spacing: 8) {
                                            // Toggle plugin enabled / disabled
                                            Toggle("", isOn: Binding(
                                                get: { plugin.isEnabled },
                                                // SwiftUI Binding bridges the Toggle to the client's method since the manifest is a value type held in an array.
                                                set: { hubClient.togglePlugin(id: plugin.id, isEnabled: $0) }
                                            ))
                                            .labelsHidden()

                                            // Uninstall plugin button
                                            Button(action: {
                                                hubClient.uninstallPlugin(id: plugin.id)
                                            }) {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red)
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                    } else {
                                        // Install plugin button
                                        Button(action: {
                                            // Result is ignored, so a failed install shows no error to the user.
                                            hubClient.installPlugin(manifest: plugin) { _ in }
                                        }) {
                                            Text("Install")
                                                .font(.subheadline)
                                                .bold()
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 4)
                                                .background(Color.accentColor)
                                                .foregroundColor(.white)
                                                .cornerRadius(8)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }

                                Text(plugin.summary)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)

                                // Semantic Category Tags
                                HStack {
                                    ForEach(plugin.tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(UIColor.tertiarySystemFill))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)

                // Native search bar (iOS 15 and later); it only edits searchText, and filteredPlugins does the work.
                .searchable(text: $searchText, prompt: "Search Plugin Hub...")
            }
            .navigationTitle("Plugin Hub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
