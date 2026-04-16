//
//  ProwlLogFormatter.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//

import Foundation
import ProwlCore

public enum ProwlExportFormat: String, Sendable {
    case formattedText
    case curlCommands

    public var fileName: String {
        switch self {
        case .formattedText: return "prowl-logs.txt"
        case .curlCommands: return "prowl-curl.sh"
        }
    }
}

public enum ProwlLogFormatter {
    public static func export(logs: [NetworkLog], as format: ProwlExportFormat) -> String {
        switch format {
        case .formattedText:
            return formattedText(logs: logs)
        case .curlCommands:
            return curlBundle(logs: logs)
        }
    }

    public static func prettyBodyText(from body: NetworkLog.Body) -> String {
        if isJSONContentType(body.contentType),
           let object = try? JSONSerialization.jsonObject(with: body.data),
           let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: prettyData, encoding: .utf8) {
            return string
        }

        if let utf8 = String(data: body.data, encoding: .utf8) {
            return utf8
        }

        return body.data.base64EncodedString()
    }

    private static func formattedText(logs: [NetworkLog]) -> String {
        logs.map { log in
            [
                "=== \(log.method) \(log.url?.absoluteString ?? "-")",
                "Status: \(log.statusCode.map(String.init) ?? "N/A")",
                "Started: \(log.startedAt)",
                "Duration: \(String(format: "%.3f", log.duration))s",
                "Request Headers: \(log.requestHeaders)",
                "Response Headers: \(log.responseHeaders)",
                "Request Body:\n\(log.requestBody.map(prettyBodyText(from:)) ?? "-")",
                "Response Body:\n\(log.responseBody.map(prettyBodyText(from:)) ?? "-")",
                "Error: \(log.errorDescription ?? "-")"
            ].joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    private static func curlBundle(logs: [NetworkLog]) -> String {
        logs.map(curlCommand(for:)).joined(separator: "\n\n")
    }

    private static func curlCommand(for log: NetworkLog) -> String {
        var command = "curl -X \(log.method)"
        for key in log.requestHeaders.keys.sorted() {
            let value = log.requestHeaders[key] ?? ""
            command += " -H '\(escape(value: "\(key): \(value)"))'"
        }

        if let requestBody = log.requestBody,
           let utf8 = String(data: requestBody.data, encoding: .utf8),
           !utf8.isEmpty {
            command += " --data '\(escape(value: utf8))'"
        }

        command += " '\(log.url?.absoluteString ?? "")'"
        return command
    }

    private static func isJSONContentType(_ contentType: String?) -> Bool {
        guard let contentType else { return false }
        return contentType.lowercased().contains("application/json")
    }

    private static func escape(value: String) -> String {
        value.replacingOccurrences(of: "'", with: "'\"'\"'")
    }
}
