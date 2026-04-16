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
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    public let log: NetworkLog
    @State private var selectedTab: Tab = .overview
    @State private var sharePayload: ProwlExportPayload?
    @State private var isBodyPretty: Bool = true

    public init(log: NetworkLog) {
        self.log = log
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Section", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            Group {
                switch selectedTab {
                case .overview:
                    overviewView
                case .headers:
                    headersView
                case .body:
                    bodyView
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
                    Button("Share JSON") {
                        shareCurrentLogJSON()
                    }
                    Button("Share cURL") {
                        shareCurrentLogCURL()
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(item: $sharePayload) { payload in
            ProwlActivityView(activityItems: [payload.content])
        }
    }

    private var overviewView: some View {
        ScrollView {
            VStack(spacing: 16) {
                timingCard

                VStack(spacing: 0) {
                    overviewRow(title: "URL", value: log.url?.absoluteString ?? "-")
                    overviewRow(title: "Method", value: log.method)
                    overviewRow(
                        title: "Status", value: log.statusCode.map(String.init) ?? "No response",
                        emphasized: !(200...299 ~= (log.statusCode ?? 0)))
                    overviewRow(
                        title: "Timestamp",
                        value: Self.timestampFormatter.string(from: log.startedAt),
                        isLast: log.errorDescription == nil)

                    if let err = log.errorDescription {
                        overviewRow(title: "Error", value: err, emphasized: true, isLast: true)
                    }
                }
                .background(platformSecondaryBackground)
                .cornerRadius(12)
            }
            .padding()
        }
    }

    private var timingCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Duration")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.3fs", log.duration))
                    .font(.title3.weight(.bold).monospacedDigit())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Started At")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(Self.timestampFormatter.string(from: log.startedAt))
                    .font(.subheadline.weight(.medium))
            }
        }
        .padding()
        .background(platformSecondaryBackground)
        .cornerRadius(12)
    }

    private func overviewRow(
        title: String, value: String, emphasized: Bool = false, isLast: Bool = false
    ) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(.subheadline.monospaced())
                .foregroundColor(emphasized ? .red : .primary)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding()
        .overlay(
            Group {
                if !isLast {
                    Divider()
                        .padding(.leading, 106)  // Align with the value offset
                }
            },
            alignment: .bottom
        )
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
                Text(title)
                    .font(.headline)
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
                Text("No headers")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                Toggle("Pretty Print JSON", isOn: $isBodyPretty)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal)
                    .padding(.top, 8)

                bodySection(title: "Request Body", body: log.requestBody)
                bodySection(title: "Response Body", body: log.responseBody)
            }
            .padding(.bottom, 24)
        }
    }

    private func bodySection(title: String, body: NetworkLog.Body?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal)
                Spacer()
                if let body, !body.data.isEmpty {
                    Button("Copy") {
                        let text = bodyText(from: body, pretty: isBodyPretty)
                        copyToPasteboard(text)
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1), in: Capsule())
                    .padding(.trailing)
                }
            }

            if let body, !body.data.isEmpty {
                let rendered = bodyText(from: body, pretty: isBodyPretty)
                Text(ProwlJSONSyntaxHighlighter.highlight(rendered, contentType: body.contentType))
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(platformSecondaryBackground, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
            } else {
                Text("No body")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Helpers

    private func bodyText(from body: NetworkLog.Body, pretty: Bool) -> String {
        if pretty {
            return ProwlLogFormatter.prettyBodyText(from: body)
        } else {
            return String(data: body.data, encoding: .utf8) ?? body.data.base64EncodedString()
        }
    }

    private func copyToPasteboard(_ string: String) {
        #if os(iOS) || os(visionOS)
            UIPasteboard.general.string = string
        #elseif os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(string, forType: .string)
        #endif
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

    private func shareCurrentLogJSON() {
        var logDict: [String: Any] = [
            "id": log.id.uuidString,
            "url": log.url?.absoluteString ?? "",
            "method": log.method,
            "startedAt": Self.timestampFormatter.string(from: log.startedAt),
            "duration": log.duration,
            "requestHeaders": log.requestHeaders,
            "responseHeaders": log.responseHeaders,
        ]

        if let statusCode = log.statusCode {
            logDict["statusCode"] = statusCode
        } else {
            logDict["error"] = log.errorDescription ?? "Unknown"
        }

        if let req = log.requestBody {
            if let obj = try? JSONSerialization.jsonObject(with: req.data) {
                logDict["requestBody"] = obj
            } else if let str = String(data: req.data, encoding: .utf8) {
                logDict["requestBody"] = str
            }
        }

        if let res = log.responseBody {
            if let obj = try? JSONSerialization.jsonObject(with: res.data) {
                logDict["responseBody"] = obj
            } else if let str = String(data: res.data, encoding: .utf8) {
                logDict["responseBody"] = str
            }
        }

        var options: JSONSerialization.WritingOptions = [.prettyPrinted]
        if #available(iOS 11.0, macOS 10.13, *) {
            options.insert(.sortedKeys)
        }

        if let data = try? JSONSerialization.data(withJSONObject: logDict, options: options),
            let string = String(data: data, encoding: .utf8)
        {
            sharePayload = ProwlExportPayload(content: string)
        }
    }

    private func shareCurrentLogCURL() {
        let content = ProwlLogFormatter.export(logs: [log], as: .curlCommands)
        sharePayload = ProwlExportPayload(content: content)
    }
}
