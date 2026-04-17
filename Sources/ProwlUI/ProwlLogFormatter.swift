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
        // Unconditionally attempt JSON formatting for maximum pretty-ness.
        if let object = try? JSONSerialization.jsonObject(with: body.data),
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        
        return logs.map { log in
            var components: [String] = []
            
            // INFO
            components.append("** INFO **")
            components.append("[URL]\n\(log.url?.absoluteString ?? "-")\n")
            components.append("[Method]\n\(log.method)\n")
            components.append("[Status]\n\(log.statusCode.map(String.init) ?? "N/A")\n")
            
            components.append("[Request date]\n\(dateFormatter.string(from: log.startedAt))\n")
            components.append("[Response date]\n\(dateFormatter.string(from: log.startedAt.addingTimeInterval(log.duration)))\n")
            components.append("[Time interval]\n\(String(format: "%.6f", log.duration))\n")
            
            if let error = log.errorDescription {
                components.append("[Error]\n\(error)\n")
            }
            
            // REQUEST
            components.append("** REQUEST **")
            components.append("-- Headers --\n")
            for key in log.requestHeaders.keys.sorted() {
                components.append("[\(key)]\n\(log.requestHeaders[key] ?? "")\n")
            }
            
            components.append("-- Body --\n")
            if let requestBody = log.requestBody, !requestBody.data.isEmpty {
                components.append("\(prettyBodyText(from: requestBody))\n")
            } else {
                components.append("Request body is empty\n")
            }
            
            // RESPONSE
            components.append("** RESPONSE **")
            components.append("-- Headers --\n")
            for key in log.responseHeaders.keys.sorted() {
                components.append("[\(key)]\n\(log.responseHeaders[key] ?? "")\n")
            }
            
            components.append("-- Body --\n")
            if let responseBody = log.responseBody, !responseBody.data.isEmpty {
                components.append("\(prettyBodyText(from: responseBody))\n")
            } else {
                components.append("Response body is empty\n")
            }
            
            return components.joined(separator: "\n")
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

    private static func isJSONContentType(_ contentType: String?) -> Bool {
        guard let contentType else { return false }
        return contentType.lowercased().contains("application/json")
    }

    private static func escape(value: String) -> String {
        value.replacingOccurrences(of: "'", with: "'\"'\"'")
    }
}
