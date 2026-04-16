//
//  ProwlLogDetailView.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//

import SwiftUI
import ProwlCore

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

    public init(log: NetworkLog) {
        self.log = log
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Section", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

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
        .padding()
    }

    private var overviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                overviewRow(title: "Method", value: log.method)
                overviewRow(title: "URL", value: log.url?.absoluteString ?? "-")
                overviewRow(title: "Status", value: log.statusCode.map(String.init) ?? "No response")
                overviewRow(title: "Duration", value: String(format: "%.3fs", log.duration))
                overviewRow(title: "Timestamp", value: Self.timestampFormatter.string(from: log.startedAt))
                if let errorDescription = log.errorDescription {
                    overviewRow(title: "Error", value: errorDescription, emphasized: true)
                }
            }
        }
    }

    private var headersView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection(title: "Request Headers", headers: log.requestHeaders)
                headerSection(title: "Response Headers", headers: log.responseHeaders)
            }
        }
    }

    private var bodyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                bodySection(title: "Request Body", body: log.requestBody)
                bodySection(title: "Response Body", body: log.responseBody)
            }
        }
    }

    private func overviewRow(title: String, value: String, emphasized: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.monospaced())
                .foregroundStyle(emphasized ? .red : .primary)
                .textSelection(.enabled)
        }
    }

    private func headerSection(title: String, headers: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            if headers.isEmpty {
                Text("No headers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(headers.keys.sorted(), id: \.self) { key in
                    HStack(alignment: .top, spacing: 8) {
                        Text(key)
                            .font(.caption.bold())
                            .frame(width: 120, alignment: .leading)
                        Text(headers[key] ?? "")
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func bodySection(title: String, body: NetworkLog.Body?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            if let body, !body.data.isEmpty {
                let rendered = ProwlLogFormatter.prettyBodyText(from: body)
                Text(ProwlJSONSyntaxHighlighter.highlight(rendered, contentType: body.contentType))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            } else {
                Text("No body")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
