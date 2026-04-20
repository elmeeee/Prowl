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

    private static let detailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter
    }()
    private static let swipeMinimumDistance: CGFloat = 14
    private static let swipeCommitDistance: CGFloat = 28
    private static let swipeVelocityBoostDistance: CGFloat = 44
    private static let swipeHorizontalDominanceRatio: CGFloat = 1.25

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
                .padding(.horizontal, 16)
                .padding(.top, 22)
                .padding(.bottom, 14)

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
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: Self.swipeMinimumDistance)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        let predictedHorizontal = value.predictedEndTranslation.width
                        guard shouldSwitchTab(
                            horizontalTranslation: horizontal,
                            verticalTranslation: vertical,
                            predictedHorizontalTranslation: predictedHorizontal
                        ) else { return }
                        moveTab(isSwipeLeft: effectiveHorizontalTranslation(horizontal: horizontal, predictedHorizontal: predictedHorizontal) < 0)
                    }
            )

            footerCreditView
                .padding(.bottom, 10)
        }
        .background(platformBackground)
        .navigationTitle("Details")
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
        HStack(spacing: 8) {
            ForEach(Tab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? platformSelectedTabBackground : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tab.rawValue) tab")
                .accessibilityHint("Shows \(tab.rawValue.lowercased()) details")
                .accessibilityAddTraits(selectedTab == tab ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(6)
        .background(
            Capsule()
                .fill(platformSecondaryBackground)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    private var infoTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionCard(title: "Endpoint") {
                VStack(alignment: .leading, spacing: 8) {
                    labeledValue("URL", value: log.url?.absoluteString ?? "-")
                    Divider()
                    HStack(spacing: 10) {
                        capsuleTag(text: log.method.uppercased(), color: .blue)
                        capsuleTag(text: "Status \(log.statusCode.map { String($0) } ?? "N/A")", color: statusColor(log.statusCode))
                    }
                }
            }

            sectionCard(title: "Timing") {
                VStack(alignment: .leading, spacing: 10) {
                    labeledValue("Request Time", value: Self.detailDateFormatter.string(from: log.startedAt))
                    labeledValue("Response Time", value: Self.detailDateFormatter.string(from: log.startedAt.addingTimeInterval(log.duration)))
                    labeledValue("Duration", value: String(format: "%.8f s", log.duration))
                    labeledValue("Timeout", value: log.timeoutInterval.map { String($0) } ?? "-")
                    labeledValue("Cache Policy", value: log.cachePolicy ?? "-")
                    if let error = log.errorDescription, !error.isEmpty {
                        labeledValue("Error", value: error)
                    }
                }
            }
        }
    }

    private var requestTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Request") {
                copyToPasteboard(requestDumpText(), toastMessage: "Request copied")
            }
            sectionCard(title: "Headers") {
                headerList(log.requestHeaders)
            }
            sectionCard(title: "Body") {
                bodyView(log.requestBody, emptyText: "Request body is empty")
            }
        }
    }

    private var responseTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Response") {
                copyToPasteboard(responseDumpText(), toastMessage: "Response copied")
            }
            sectionCard(title: "Headers") {
                headerList(log.responseHeaders)
            }
            sectionCard(title: "Body") {
                bodyView(log.responseBody, emptyText: "Response body is empty")
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(title: String, onCopy: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Button("Copy") {
                onCopy()
            }
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.blue.opacity(0.1), in: Capsule())
            .accessibilityLabel("Copy \(title)")
            .accessibilityHint("Copies \(title.lowercased()) section to clipboard")
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(platformSecondaryBackground)
        )
    }

    @ViewBuilder
    private func labeledValue(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func capsuleTag(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.monospaced().weight(.bold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15), in: Capsule())
    }

    @ViewBuilder
    private func headerList(_ headers: [String: String]) -> some View {
        if headers.isEmpty {
            Text("No headers")
                .font(.subheadline)
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(headers.keys.sorted(), id: \.self) { key in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(key)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
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
    private func bodyView(_ body: NetworkLog.Body?, emptyText: String) -> some View {
        let text = bodyText(body, emptyText: emptyText)
        Text(text)
            .font(.footnote.monospaced())
            .foregroundColor(.primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(platformBodyBackground)
            )
    }

    private func bodyText(_ body: NetworkLog.Body?, emptyText: String) -> String {
        guard let body, !body.data.isEmpty else { return emptyText }
        return ProwlLogFormatter.bodyText(from: body, pretty: true)
    }

    private func requestDumpText() -> String {
        var lines: [String] = []
        lines.append("Headers")
        for key in log.requestHeaders.keys.sorted() {
            lines.append("\(key): \(log.requestHeaders[key] ?? "")")
        }
        lines.append("")
        lines.append("Body")
        lines.append(bodyText(log.requestBody, emptyText: "Request body is empty"))
        return lines.joined(separator: "\n")
    }

    private func responseDumpText() -> String {
        var lines: [String] = []
        lines.append("Headers")
        for key in log.responseHeaders.keys.sorted() {
            lines.append("\(key): \(log.responseHeaders[key] ?? "")")
        }
        lines.append("")
        lines.append("Body")
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

    private func shouldSwitchTab(
        horizontalTranslation: CGFloat,
        verticalTranslation: CGFloat,
        predictedHorizontalTranslation: CGFloat
    ) -> Bool {
        let horizontalAbs = abs(horizontalTranslation)
        let verticalAbs = abs(verticalTranslation)
        let predictedAbs = abs(predictedHorizontalTranslation)

        // Ignore mostly-vertical drags so scroll remains natural.
        guard horizontalAbs > (verticalAbs * Self.swipeHorizontalDominanceRatio) else { return false }

        // Accept either direct distance or a short-but-fast flick.
        return horizontalAbs >= Self.swipeCommitDistance || predictedAbs >= Self.swipeVelocityBoostDistance
    }

    private func effectiveHorizontalTranslation(horizontal: CGFloat, predictedHorizontal: CGFloat) -> CGFloat {
        if abs(predictedHorizontal) > abs(horizontal) {
            return predictedHorizontal
        }
        return horizontal
    }

    @ViewBuilder
    private var footerCreditView: some View {
        HStack(spacing: 4) {
            Text("Copyright © 2026 Elmee")
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

    private func statusColor(_ code: Int?) -> Color {
        guard let code else { return .red }
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

    private var platformSelectedTabBackground: Color {
        #if os(iOS) || os(visionOS)
        return Color(UIColor.tertiarySystemGroupedBackground)
        #elseif os(macOS)
        return Color(NSColor.quaternaryLabelColor).opacity(0.12)
        #else
        return Color.primary.opacity(0.08)
        #endif
    }

    private var platformBodyBackground: Color {
        #if os(iOS) || os(visionOS)
        return Color(UIColor.systemBackground).opacity(0.7)
        #elseif os(macOS)
        return Color(NSColor.textBackgroundColor).opacity(0.7)
        #else
        return Color.primary.opacity(0.05)
        #endif
    }
}
