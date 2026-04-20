//
//  ProwlLogDetailView.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
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
        case info = "Info"
        case request = "Request"
        case response = "Response"
        public var id: String { rawValue }
    }

    private static let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter
    }()

    public let log: NetworkLog

    @State private var selectedTab: Tab = .info
    @State private var sharePayload: ProwlExportPayload?
    @State private var isMockEditorPresented = false
    @State private var copyToastMessage: String?
    @State private var copyToastToken = UUID()

    public init(log: NetworkLog) {
        self.log = log
    }

    public var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.top, 8)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                Group {
                    switch selectedTab {
                    case .info:
                        infoTabContent
                    case .request:
                        requestTabContent
                    case .response:
                        responseTabContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        guard abs(horizontal) > abs(vertical), abs(horizontal) > 50 else { return }
                        moveTab(isSwipeLeft: horizontal < 0)
                    }
            )

            footerCreditView
                .padding(.bottom, 10)
        }
        .background(platformBackground)
        .navigationTitle("Details Response")
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Share JSON") {
                        shareContent(ProwlLogFormatter.shareText(log: log))
                    }
                    Button("Share cURL") {
                        shareContent(ProwlLogFormatter.export(logs: [log], as: .curlCommands))
                    }
                    Button("Create Mock") {
                        isMockEditorPresented = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        #if os(iOS) || os(visionOS)
        .sheet(item: $sharePayload) { payload in
            ProwlActivityView(activityItems: [payload.content])
        }
        #endif
        .sheet(isPresented: $isMockEditorPresented) {
            ProwlMockEditorView(log: log)
        }
        .overlay(alignment: .bottom) {
            if let copyToastMessage {
                copyToastView(message: copyToastMessage)
                    .padding(.bottom, 22)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(selectedTab == tab ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Group {
                                if selectedTab == tab {
                                    LinearGradient(
                                        colors: [Color.purple, Color.pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                } else {
                                    Color.clear
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tab.rawValue) tab")
                .accessibilityHint("Shows \(tab.rawValue.lowercased()) details")
                .accessibilityAddTraits(selectedTab == tab ? [.isButton, .isSelected] : .isButton)
            }
        }
        .background(platformSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
    }

    private var infoTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            infoRow("[URL]", log.url?.absoluteString ?? "-")
            infoRow("[Method]", log.method)
            infoRow("[Status]", log.statusCode.map { String($0) } ?? "N/A")
            infoRow("[Request date]", Self.exportDateFormatter.string(from: log.startedAt))
            infoRow("[Response date]", Self.exportDateFormatter.string(from: log.startedAt.addingTimeInterval(log.duration)))
            infoRow("[Time interval]", String(format: "%.8f", log.duration))
            infoRow("[Timeout]", log.timeoutInterval.map { String($0) } ?? "-")
            infoRow("[Cache policy]", log.cachePolicy ?? "-")
            if let error = log.errorDescription, !error.isEmpty {
                infoRow("[Error]", error)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var requestTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            copyButton(title: "Copy Request") {
                copyToPasteboard(requestDumpText(), toastMessage: "Request copied")
            }
            sectionTitle("-- Headers --")
            headerList(log.requestHeaders)
            sectionTitle("-- Body --")
            bodyBlock(text: bodyText(log.requestBody, emptyText: "Request body is empty"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var responseTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            copyButton(title: "Copy Response") {
                copyToPasteboard(responseDumpText(), toastMessage: "Response copied")
            }
            sectionTitle("-- Headers --")
            headerList(log.responseHeaders)
            sectionTitle("-- Body --")
            bodyBlock(text: bodyText(log.responseBody, emptyText: "Response body is empty"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func infoRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)
                .foregroundColor(.blue.opacity(0.9))
            Text(value)
                .font(.body)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.bold))
            .foregroundColor(.purple.opacity(0.9))
    }

    @ViewBuilder
    private func headerList(_ headers: [String: String]) -> some View {
        if headers.isEmpty {
            Text("No headers")
                .font(.body)
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(headers.keys.sorted(), id: \.self) { key in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("[\(key)]")
                            .font(.headline)
                            .foregroundColor(.blue.opacity(0.9))
                        Text(headers[key] ?? "")
                            .font(.body)
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bodyBlock(text: String) -> some View {
        Text(text)
            .font(.body.monospaced())
            .foregroundColor(.primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bodyText(_ body: NetworkLog.Body?, emptyText: String) -> String {
        guard let body, !body.data.isEmpty else { return emptyText }
        return ProwlLogFormatter.bodyText(from: body, pretty: true)
    }

    private func requestDumpText() -> String {
        var lines: [String] = []
        lines.append("-- Headers --")
        for key in log.requestHeaders.keys.sorted() {
            lines.append("[\(key)]")
            lines.append(log.requestHeaders[key] ?? "")
        }
        lines.append("-- Body --")
        lines.append(bodyText(log.requestBody, emptyText: "Request body is empty"))
        return lines.joined(separator: "\n")
    }

    private func responseDumpText() -> String {
        var lines: [String] = []
        lines.append("-- Headers --")
        for key in log.responseHeaders.keys.sorted() {
            lines.append("[\(key)]")
            lines.append(log.responseHeaders[key] ?? "")
        }
        lines.append("-- Body --")
        lines.append(bodyText(log.responseBody, emptyText: "Response body is empty"))
        return lines.joined(separator: "\n")
    }

    private func moveTab(isSwipeLeft: Bool) {
        let allTabs = Tab.allCases
        guard let currentIndex = allTabs.firstIndex(of: selectedTab) else { return }

        let nextIndex: Int
        if isSwipeLeft {
            nextIndex = min(currentIndex + 1, allTabs.count - 1)
        } else {
            nextIndex = max(currentIndex - 1, 0)
        }

        guard nextIndex != currentIndex else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTab = allTabs[nextIndex]
        }
    }

    @ViewBuilder
    private func copyButton(title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Button(title) {
                action()
            }
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1), in: Capsule())
            .accessibilityLabel(title)
            .accessibilityHint("Copies this section to clipboard")
        }
    }

    @ViewBuilder
    private var footerCreditView: some View {
        HStack(spacing: 4) {
            Text("ini karya gua bro")
                .foregroundColor(.secondary)
            if let siteURL = URL(string: "https://elmee.my") {
                Link("elmee.my", destination: siteURL)
                    .foregroundColor(.accentColor)
            }
        }
        .font(.caption2)
        .lineLimit(1)
    }

    @ViewBuilder
    private func copyToastView(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }

    private func shareContent(_ content: String) {
        #if os(macOS)
        ProwlMacExporter.save(content: content, suggestedFileName: "prowl-log.txt")
        #else
        sharePayload = ProwlExportPayload(content: content)
        #endif
    }

    private func copyToPasteboard(_ string: String, toastMessage: String = "Copied") {
        #if os(iOS) || os(visionOS)
        UIPasteboard.general.string = string
        #elseif os(macOS)
        let p = NSPasteboard.general
        p.clearContents()
        p.setString(string, forType: .string)
        #endif
        triggerCopyFeedback()
        showCopyToast(toastMessage)
    }

    private func triggerCopyFeedback() {
        #if os(iOS) || os(visionOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    private func showCopyToast(_ message: String) {
        let token = UUID()
        copyToastToken = token
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            copyToastMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            guard copyToastToken == token else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                copyToastMessage = nil
            }
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
}
