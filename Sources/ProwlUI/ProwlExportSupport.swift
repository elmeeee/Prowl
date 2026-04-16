//
//  ProwlExportSupport.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//

import Foundation

public struct ProwlExportPayload: Identifiable {
    public let id = UUID()
    public let content: String

    public init(content: String) {
        self.content = content
    }
}

#if os(iOS)
import SwiftUI
import UIKit

public struct ProwlActivityView: UIViewControllerRepresentable {
    public let activityItems: [Any]

    public init(activityItems: [Any]) {
        self.activityItems = activityItems
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
import SwiftUI

public struct ProwlActivityView: View {
    public let activityItems: [Any]

    public init(activityItems: [Any]) {
        self.activityItems = activityItems
    }

    public var body: some View {
        EmptyView()
    }
}
#endif

#if os(macOS)
import AppKit

public enum ProwlMacExporter {
    @MainActor
    public static func save(content: String, suggestedFileName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFileName
        panel.allowedContentTypes = [.text]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }
}
#endif
