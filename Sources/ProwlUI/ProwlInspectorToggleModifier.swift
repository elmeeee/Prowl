//
//  ProwlInspectorToggleModifier.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//

import SwiftUI
import ProwlCore

public struct ProwlInspectorToggleModifier: ViewModifier {
    private let storage: ProwlStorage?

    @State private var isPresented = false

    public init(storage: ProwlStorage? = nil) {
        self.storage = storage
    }

    public func body(content: Content) -> some View {
        content
            .background(
                ProwlShakeDetector {
                    isPresented.toggle()
                }
            )
#if os(macOS)
            .overlay(alignment: .topTrailing) {
                Button(action: { isPresented.toggle() }) {
                    EmptyView()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .frame(width: 0, height: 0)
                .opacity(0.001)
            }
#endif
            .sheet(isPresented: $isPresented) {
                ProwlInspectorView(storage: storage)
            }
    }
}

public extension View {
    func prowlInspector(storage: ProwlStorage? = nil) -> some View {
        modifier(ProwlInspectorToggleModifier(storage: storage))
    }
}
