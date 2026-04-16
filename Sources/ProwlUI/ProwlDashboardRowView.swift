//
//  ProwlDashboardRowView.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(log.method)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.thinMaterial, in: Capsule())

                statusView
                Spacer(minLength: 12)
                Text(Self.timestampFormatter.string(from: log.startedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(log.url?.path.isEmpty == false ? (log.url?.path ?? "/") : "/")
                .font(.body.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusView: some View {
        if let statusCode = log.statusCode {
            Text("\(statusCode)")
                .font(.caption.weight(.medium))
                .foregroundStyle(color(for: statusCode))
        } else {
            Text("ERR")
                .font(.caption.weight(.medium))
                .foregroundStyle(.red)
        }
    }

    private func color(for statusCode: Int) -> Color {
        switch statusCode {
        case 200...299:
            return .green
        case 400...599:
            return .red
        default:
            return .orange
        }
    }
}
