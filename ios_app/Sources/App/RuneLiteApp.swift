//
//  RuneLiteApp.swift
//  RuneLiteMobile
//
//  Created for iOS Standalone RuneLite Client Architecture.
//  Copyright © 2026 TWU LLC. All rights reserved.
//

import SwiftUI

/// Root SwiftUI Application interface if compiled in pure SwiftUI mode
public struct RuneLiteRootView: View {
    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("RuneLite Mobile Engine Active")
                .foregroundColor(.green)
                .font(.headline)
        }
    }
}
