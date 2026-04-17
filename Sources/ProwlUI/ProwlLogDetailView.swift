//
//  ProwlLogDetailView.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//

import ProwlCore
import SwiftUI

#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct ProwlLogDetailView: View {
    public enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case headers = "Headers"
        case body = "Body"
        public var id: String { rawValue }
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    public let log: NetworkLog

    @StateObject private var viewModel: ProwlLogDetailViewModel
    @State private var selectedTab: Tab = .overview
    @State private var sharePayload: ProwlExportPayload?
    @State private var isMockEditorPresented = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init(log: NetworkLog) {
        self.log = log
        _viewModel = StateObject(wrappedValue: ProwlLogDetailViewModel(log: log))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Section", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, segmentedPickerHorizontalPadding)
            .padding(.vertical, 8)

            Divider()

            Group {
                switch selectedTab {
                case .overview: overviewView
                case .headers: headersView
                case .body: bodyView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(platformBackground)
        .navigationTitle("Details")
        #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Share JSON") { viewModel.handle(.shareJSON) }
                    Button("Share cURL") { viewModel.handle(.shareCURL) }
                    Button("Create Mock") { isMockEditorPresented = true }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .onChange(of: viewModel.shareContent) { content in
            if let content {
                sharePayload = ProwlExportPayload(content: content)
            }
        }
        .onChange(of: viewModel.pasteboardString) { str in
            if let str { copyToPasteboard(str) }
        }
        .sheet(item: $sharePayload) { payload in
            ProwlActivityView(activityItems: [payload.content])
        }
        .sheet(isPresented: $isMockEditorPresented) {
            ProwlMockEditorView(log: log)
        }
    }

    private var overviewView: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("STATUS")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.secondary)
                        statusBadge(statusCode: log.statusCode)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("METHOD")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.secondary)
                        methodBadge(log.method)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(platformSecondaryBackground)
                .cornerRadius(16)

                timingCard

                VStack(spacing: 16) {
                    urlSection(title: "HOST", value: log.url?.host ?? "")
                    Divider()
                    urlSection(title: "PATH", value: log.url?.path.isEmpty == false ? (log.url?.path ?? "/") : "/")
                    Divider()
                    urlSection(title: "FULL URL", value: log.url?.absoluteString ?? "-")

                    if let err = log.errorDescription {
                        Divider()
                        urlSection(title: "ERROR", value: err, emphasized: true)
                    }
                }
                .padding(16)
                .background(platformSecondaryBackground)
                .cornerRadius(16)
            }
            .padding()
        }
    }

    private var timingCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("TOTAL DURATION")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)
                Text(String(format: "%.3f", log.duration))
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundColor(.primary)
                + Text("s")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("STARTED AT")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)
                Text(Self.timestampFormatter.string(from: log.startedAt))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
        }
        .padding(16)
        .background(platformSecondaryBackground)
        .cornerRadius(16)
    }

    @ViewBuilder
    private func urlSection(title: String, value: String, emphasized: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.body.monospaced())
                .foregroundColor(emphasized ? .red : .primary)
                .textSelection(.enabled)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headersView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection(title: "Request Headers", headers: log.requestHeaders)
                headerSection(title: "Response Headers", headers: log.responseHeaders)
            }
            .padding()
        }
    }

    private func headerSection(title: String, headers: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if !headers.isEmpty {
                    Button("Copy") {
                        let text = headers.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
                        copyToPasteboard(text)
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1), in: Capsule())
                }
            }

            if headers.isEmpty {
                Text("No headers").font(.caption).foregroundColor(.secondary)
            } else {
                VStack(spacing: 0) {
                    let sortedKeys = headers.keys.sorted()
                    ForEach(Array(sortedKeys.enumerated()), id: \.element) { index, key in
                        HStack(alignment: .top, spacing: 12) {
                            Text(key)
                                .font(.caption.weight(.bold))
                                .frame(width: 120, alignment: .leading)
                            Text(headers[key] ?? "")
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(index % 2 == 0 ? Color.clear : Color.primary.opacity(0.03))
                    }
                }
                .background(platformSecondaryBackground)
                .cornerRadius(8)
            }
        }
    }

    private var bodyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Toggle("Pretty Print JSON", isOn: Binding(
                    get: { viewModel.isPretty },
                    set: { _ in viewModel.handle(.togglePrettyPrint) }
                ))
                .font(.subheadline.weight(.medium))
                .padding(.horizontal)
                .padding(.top, 8)

                renderableSection(title: "Request Body", renderable: viewModel.requestBody, isRequest: true)
                renderableSection(title: "Response Body", renderable: viewModel.responseBody, isRequest: false)
            }
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func renderableSection(title: String, renderable: ProwlBodyRenderable, isRequest: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline).padding(.horizontal)
                Spacer()
                if case .empty = renderable { } else {
                    Button("Copy") { viewModel.handle(.copyBody(isRequest: isRequest)) }
                        .font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1), in: Capsule())
                        .padding(.trailing)
                }
            }

            switch renderable {
            case .text(let attributed):
                Text(attributed)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(platformSecondaryBackground, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

            case .image(let data):
                imageView(data: data)

            case .empty:
                Text("No body")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func imageView(data: Data) -> some View {
        #if os(iOS) || os(visionOS)
        if let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 300)
                .cornerRadius(12)
                .padding(.horizontal)
        }
        #elseif os(macOS)
        if let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 300)
                .cornerRadius(12)
                .padding(.horizontal)
        }
        #endif
    }

    @ViewBuilder
    private func methodBadge(_ method: String) -> some View {
        Text(method.uppercased())
            .font(.caption.monospaced().weight(.bold))
            .foregroundColor(methodColor(method))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(methodColor(method).opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func statusBadge(statusCode: Int?) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor(statusCode))
                .frame(width: 8, height: 8)
            Text(statusCode.map { "\($0)" } ?? "ERR")
                .font(.caption.monospaced().weight(.bold))
                .foregroundColor(statusColor(statusCode))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(statusColor(statusCode).opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
    }

    private func methodColor(_ method: String) -> Color {
        switch method.uppercased() {
        case "GET": return .blue
        case "POST": return .green
        case "PUT", "PATCH": return .orange
        case "DELETE": return .red
        default: return .secondary
        }
    }

    private func statusColor(_ statusCode: Int?) -> Color {
        guard let code = statusCode else { return .red }
        switch code {
        case 200...299: return .green
        case 300...399: return .blue
        case 400...499: return .orange
        case 500...599: return .red
        default: return .secondary
        }
    }

    private var platformBackground: Color {
        #if os(iOS) || os(visionOS)
            return Color(UIColor.systemGroupedBackground)
        #elseif os(macOS)
            return Color(NSColor.windowBackgroundColor)
        #else
            return .clear
        #endif
    }

    private var platformSecondaryBackground: Color {
        #if os(iOS) || os(visionOS)
            return Color(UIColor.secondarySystemGroupedBackground)
        #elseif os(macOS)
            return Color(NSColor.controlBackgroundColor)
        #else
            return .clear
        #endif
    }

    private var segmentedPickerHorizontalPadding: CGFloat {
        #if os(iOS) || os(visionOS)
            return horizontalSizeClass == .compact ? 20 : 16
        #else
            return 16
        #endif
    }

    private func copyToPasteboard(_ string: String) {
        #if os(iOS) || os(visionOS)
            UIPasteboard.general.string = string
        #elseif os(macOS)
            let p = NSPasteboard.general
            p.clearContents()
            p.setString(string, forType: .string)
        #endif
    }
}
