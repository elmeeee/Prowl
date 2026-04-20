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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"

        let requestBodyText: String
        if let body = log.requestBody, !body.data.isEmpty {
            requestBodyText = prettyBodyText(from: body)
        } else {
            requestBodyText = "Request body is empty"
        }

        let responseBodyText: String
        if let body = log.responseBody, !body.data.isEmpty {
            if body.data.count > 2_000 {
                responseBodyText = "Too long to show. If you want to see it, please tap the following button"
            } else {
                responseBodyText = prettyBodyText(from: body)
            }
        } else {
            responseBodyText = "Response body is empty"
        }

        var chunks: [String] = []
        chunks.append("** INFO **")
        chunks.append("[URL] \n\(log.url?.absoluteString ?? "-")")
        chunks.append("[Method] \n\(log.method)")
        chunks.append("[Status] \n\(log.statusCode.map { String($0) } ?? "N/A")")
        chunks.append("[Request date] \n\(dateFormatter.string(from: log.startedAt))")
        chunks.append("[Response date] \n\(dateFormatter.string(from: log.startedAt.addingTimeInterval(log.duration)))")
        chunks.append("[Time interval] \n\(String(format: "%.6f", log.duration))")
        chunks.append("[Timeout] \n\(log.timeoutInterval.map { String($0) } ?? "-")")
        chunks.append("[Cache policy] \n\(log.cachePolicy ?? "-")")

        chunks.append("** REQUEST **")
        chunks.append("-- Headers --")
        for key in log.requestHeaders.keys.sorted() {
            chunks.append("[\(key)] \n\(log.requestHeaders[key] ?? "")")
        }
        chunks.append("-- Body --")
        chunks.append(requestBodyText)

        chunks.append("** RESPONSE **")
        chunks.append("-- Headers --")
        for key in log.responseHeaders.keys.sorted() {
            chunks.append("[\(key)] \n\(log.responseHeaders[key] ?? "")")
        }
        chunks.append("-- Body --")
        chunks.append(responseBodyText)
        chunks.append("logged via prowl - [https://github.com/elmeeee/prowl]")

        if let responseBody = log.responseBody, !responseBody.data.isEmpty {
            let rawResponse = String(data: responseBody.data, encoding: .utf8) ?? responseBody.data.base64EncodedString()
            chunks.append(rawResponse)
        }

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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"

        return logs.map { log in
            var c: [String] = []

            c.append("** INFO **")
            c.append("[URL]\n\(log.url?.absoluteString ?? "-")\n")
            c.append("[Method]\n\(log.method)\n")
            c.append("[Status]\n\(log.statusCode.map { String($0) } ?? "N/A")\n")
            c.append("[Request date]\n\(dateFormatter.string(from: log.startedAt))\n")
            c.append("[Response date]\n\(dateFormatter.string(from: log.startedAt.addingTimeInterval(log.duration)))\n")
            c.append("[Time interval]\n\(String(format: "%.6f", log.duration))\n")
            c.append("[Timeout]\n\(log.timeoutInterval.map { String($0) } ?? "-")\n")
            c.append("[Cache policy]\n\(log.cachePolicy ?? "-")\n")
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
