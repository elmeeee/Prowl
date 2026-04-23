//
//  ProwlLogFormatter.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
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
        if isFormURLEncoded(body.contentType),
           let formText = String(data: body.data, encoding: .utf8),
           let formatted = prettyFormURLEncodedBody(formText) {
            return formatted
        }
        if let utf8 = String(data: body.data, encoding: .utf8) { return utf8 }
        return body.data.base64EncodedString()
    }

    public static func shareText(log: NetworkLog) -> String {
        var chunks: [String] = []
        chunks.append("** INFO **")
        chunks.append(infoText(log: log))

        chunks.append("** REQUEST **")
        chunks.append(requestText(log: log, showFullBody: true))

        chunks.append("** RESPONSE **")
        chunks.append(responseText(log: log, showFullBody: true))

        if let responseBody = log.responseBody, !responseBody.data.isEmpty {
            let rawResponse = String(data: responseBody.data, encoding: .utf8) ?? responseBody.data.base64EncodedString()
            chunks.append(rawResponse)
        }

        chunks.append("logged via prowl - [https://github.com/elmeeee/prowl]")
        return chunks.joined(separator: "\n\n")
    }

    private static func isFormURLEncoded(_ contentType: String?) -> Bool {
        guard let contentType else { return false }
        return contentType.lowercased().contains("application/x-www-form-urlencoded")
    }

    private static func prettyFormURLEncodedBody(_ body: String) -> String? {
        let pairs = body.split(separator: "&", omittingEmptySubsequences: false)
        guard !pairs.isEmpty else { return nil }

        let lines = pairs.map { pair -> String in
            let components = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let rawKey = components.indices.contains(0) ? String(components[0]) : ""
            let rawValue = components.indices.contains(1) ? String(components[1]) : ""
            return "\(decodeFormComponent(rawKey)) = \(decodeFormComponent(rawValue))"
        }
        return lines.joined(separator: "\n")
    }

    private static func decodeFormComponent(_ text: String) -> String {
        let plusAsSpaces = text.replacingOccurrences(of: "+", with: " ")
        return plusAsSpaces.removingPercentEncoding ?? plusAsSpaces
    }

    private static func formattedText(logs: [NetworkLog]) -> String {
        return logs.map { log in
            var c: [String] = []

            c.append("** INFO **")
            c.append(infoText(log: log))

            c.append("** REQUEST **")
            c.append(requestText(log: log, showFullBody: true))

            c.append("** RESPONSE **")
            c.append(responseText(log: log, showFullBody: true))

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

    private static func infoText(log: NetworkLog) -> String {
        var lines: [String] = []
        lines.append("[URL] ")
        lines.append(log.url?.absoluteString ?? "-")
        lines.append("")
        lines.append("[Method] ")
        lines.append(log.method)
        lines.append("")
        if let statusCode = log.statusCode {
            lines.append("[Status] ")
            lines.append(String(statusCode))
            lines.append("")
        }
        lines.append("[Request date] ")
        lines.append(String(describing: log.startedAt))
        lines.append("")
        if hasResponse(log) {
            lines.append("[Response date] ")
            lines.append(String(describing: log.startedAt.addingTimeInterval(log.duration)))
            lines.append("")
            lines.append("[Time interval] ")
            lines.append(String(Float(log.duration)))
            lines.append("")
        }
        lines.append("[Timeout] ")
        lines.append(log.timeoutInterval.map { String($0) } ?? "-")
        lines.append("")
        lines.append("[Cache policy] ")
        lines.append(log.cachePolicy ?? "-")
        return lines.joined(separator: "\n")
    }

    private static func requestText(log: NetworkLog, showFullBody: Bool) -> String {
        var lines: [String] = []
        lines.append("-- Headers --")
        lines.append("")
        if log.requestHeaders.isEmpty {
            lines.append("Request headers are empty")
            lines.append("")
        } else {
            for key in log.requestHeaders.keys.sorted() {
                lines.append("[\(key)] ")
                lines.append(log.requestHeaders[key] ?? "")
                lines.append("")
            }
        }
        lines.append("-- Body --")
        lines.append("")
        lines.append(bodyTextNetfoxStyle(body: log.requestBody, emptyText: "Request body is empty", showFullBody: showFullBody))
        return lines.joined(separator: "\n")
    }

    private static func responseText(log: NetworkLog, showFullBody: Bool) -> String {
        guard hasResponse(log) else {
            return "No response"
        }
        var lines: [String] = []
        lines.append("-- Headers --")
        lines.append("")
        if log.responseHeaders.isEmpty {
            lines.append("Response headers are empty")
            lines.append("")
        } else {
            for key in log.responseHeaders.keys.sorted() {
                lines.append("[\(key)] ")
                lines.append(log.responseHeaders[key] ?? "")
                lines.append("")
            }
        }
        lines.append("-- Body --")
        lines.append("")
        lines.append(bodyTextNetfoxStyle(body: log.responseBody, emptyText: "Response body is empty", showFullBody: showFullBody))
        return lines.joined(separator: "\n")
    }

    private static func bodyTextNetfoxStyle(body: NetworkLog.Body?, emptyText: String, showFullBody: Bool) -> String {
        guard let body else { return emptyText }
        if body.data.isEmpty { return emptyText }
        if body.data.count > 1024 && !showFullBody {
            return "Too long to show. If you want to see it, please tap the following button"
        }
        return prettyBodyText(from: body)
    }

    private static func hasResponse(_ log: NetworkLog) -> Bool {
        log.statusCode != nil || !log.responseHeaders.isEmpty || log.responseBody != nil
    }
}
