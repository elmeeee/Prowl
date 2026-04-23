//
//  ProwlDashboardRowView.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import SwiftUI
import ProwlCore

public struct ProwlDashboardRowView: View {
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    public let log: NetworkLog

    public init(log: NetworkLog) {
        self.log = log
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                methodBadge(log.method)
                
                Text(log.url?.path.isEmpty == false ? (log.url?.path ?? "/") : "/")
                    .font(.body.monospaced().weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.primary)
                
                Spacer(minLength: 8)
                
                Text(Self.timestampFormatter.string(from: log.startedAt))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 8) {
                statusBadge(statusCode: log.statusCode)
                
                if let host = log.url?.host {
                    Text(host)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 8)
                
                Text(String(format: "%.3fs", log.duration))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func methodBadge(_ method: String) -> some View {
        Text(method.uppercased())
            .font(.caption2.monospaced().weight(.bold))
            .foregroundColor(methodColor(method))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(methodColor(method).opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func statusBadge(statusCode: Int?) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor(statusCode))
                .frame(width: 8, height: 8)
            Text(statusCode.map { "\($0)" } ?? "ERR")
                .font(.caption.monospaced().weight(.bold))
                .foregroundColor(statusColor(statusCode))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(statusColor(statusCode).opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
    }

    private func methodColor(_ method: String) -> Color {
        switch method.uppercased() {
        case "GET": return Color(red: 0.94, green: 0.42, blue: 0.16)
        case "POST": return Color(red: 0.95, green: 0.57, blue: 0.19)
        case "PUT", "PATCH": return Color(red: 0.98, green: 0.72, blue: 0.29)
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
}
