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
                // Header Metrics: Status & Method
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

                // Timing Component
                timingCard

                // Path & Routing Breakdown
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
            logDict["error"] = log.errorDescription ?? ""
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

        let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]

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

#if DEBUG
struct ProwlLogDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let dummyLog = NetworkLog(
            requestID: UUID(),
            url: URL(string: "https://api.dev.saldoo.app/report/monthly?user_id=123"),
            method: "GET",
            requestHeaders: ["Authorization": "Bearer sample_token", "Accept": "application/json"],
            requestBody: nil,
            responseHeaders: ["Content-Type": "application/json"],
            responseBody: .init(data: """
            {
                "status": "success",
                "message": "Monthly report generated successfully.",
                "data": {
                    "total_users": 1542,
                    "active_sessions": 312
                }
            }
            """.data(using: .utf8)!, contentType: "application/json"),
            statusCode: 200,
            startedAt: Date().addingTimeInterval(-1.5),
            duration: 0.213,
            errorDescription: nil
        )

        NavigationView {
            ProwlLogDetailView(log: dummyLog)
        }
    }
}
#endif
