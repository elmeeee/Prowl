//
//  ProwlLogFormatter.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//
//

import Foundation


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
        case .formattedText: return formattedText(logs: logs)
        case .curlCommands: return curlBundle(logs: logs)
        }
    }

    /// Converts raw body data to the best human-readable string representation.
    /// JSON is always pretty-printed independently of content-type header.
    public static func bodyText(from body: NetworkLog.Body, pretty: Bool) -> String {
        if pretty {
            return prettyBodyText(from: body)
        }
        return String(data: body.data, encoding: .utf8) ?? body.data.base64EncodedString()
    }

    public static func prettyBodyText(from body: NetworkLog.Body) -> String {
        // Unconditionally attempt JSON formatting for maximum readability.
        if let object = try? JSONSerialization.jsonObject(with: body.data),
           let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: prettyData, encoding: .utf8) {
            return string
        }
        if let utf8 = String(data: body.data, encoding: .utf8) { return utf8 }
        return body.data.base64EncodedString()
    }

    private static func formattedText(logs: [NetworkLog]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"

        return logs.map { log in
            var c: [String] = []

            c.append("** INFO **")
            c.append("[URL]\n\(log.url?.absoluteString ?? "-")\n")
            c.append("[Method]\n\(log.method)\n")
            c.append("[Status]\n\(log.statusCode.map(String.init) ?? "N/A")\n")
            c.append("[Request date]\n\(dateFormatter.string(from: log.startedAt))\n")
            c.append("[Response date]\n\(dateFormatter.string(from: log.startedAt.addingTimeInterval(log.duration)))\n")
            c.append("[Time interval]\n\(String(format: "%.6f", log.duration))\n")
            if let error = log.errorDescription { c.append("[Error]\n\(error)\n") }

            c.append("** REQUEST **")
            c.append("-- Headers --\n")
            for key in log.requestHeaders.keys.sorted() {
                c.append("[\(key)]\n\(log.requestHeaders[key] ?? "")\n")
            }
            c.append("-- Body --\n")
            if let body = log.requestBody, !body.data.isEmpty {
                c.append("\(prettyBodyText(from: body))\n")
            } else {
                c.append("Request body is empty\n")
            }

            c.append("** RESPONSE **")
            c.append("-- Headers --\n")
            for key in log.responseHeaders.keys.sorted() {
                c.append("[\(key)]\n\(log.responseHeaders[key] ?? "")\n")
            }
            c.append("-- Body --\n")
            if let body = log.responseBody, !body.data.isEmpty {
                c.append("\(prettyBodyText(from: body))\n")
            } else {
                c.append("Response body is empty\n")
            }

            return c.joined(separator: "\n")
        }.joined(separator: "\n\n--------------------------------------------------------------\n\n")
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

    private static func escape(value: String) -> String {
        value.replacingOccurrences(of: "'", with: "'\"'\"'")
    }
}
