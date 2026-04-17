//
//  ProwlLogDetailViewModel.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//

import Foundation
import ProwlCore
#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public enum ProwlBodyRenderable: Sendable {
    case text(AttributedString)
    case image(Data)
    case empty
}

public enum ProwlLogDetailIntent {
    case togglePrettyPrint
    case copyBody(isRequest: Bool)
    case shareJSON
    case shareCURL
}


@MainActor
public final class ProwlLogDetailViewModel: ObservableObject {

    @Published public private(set) var requestBody: ProwlBodyRenderable = .empty
    @Published public private(set) var responseBody: ProwlBodyRenderable = .empty
    @Published public private(set) var isPretty: Bool = true
    @Published public private(set) var shareContent: String? = nil
    @Published public private(set) var pasteboardString: String? = nil

    private let log: NetworkLog

    public init(log: NetworkLog) {
        self.log = log
        recompute()
    }

    public func handle(_ intent: ProwlLogDetailIntent) {
        switch intent {
        case .togglePrettyPrint:
            isPretty.toggle()
            recompute()

        case .copyBody(let isRequest):
            let body = isRequest ? log.requestBody : log.responseBody
            guard let body else { return }
            pasteboardString = ProwlLogFormatter.bodyText(from: body, pretty: isPretty)

        case .shareJSON:
            shareContent = buildJSONShare()

        case .shareCURL:
            shareContent = ProwlLogFormatter.export(logs: [log], as: .curlCommands)
        }
    }

    private func recompute() {
        requestBody = resolve(log.requestBody)
        responseBody = resolve(log.responseBody)
    }

    private func resolve(_ body: NetworkLog.Body?) -> ProwlBodyRenderable {
        guard let body, !body.data.isEmpty else { return .empty }

        let isImage = body.contentType?.lowercased().contains("image") ?? false
        if isImage { return .image(body.data) }

        let text = ProwlLogFormatter.bodyText(from: body, pretty: isPretty)
        let attributed = ProwlJSONSyntaxHighlighter.highlight(text, contentType: body.contentType)
        return .text(attributed)
    }

    private func buildJSONShare() -> String? {
        var dict: [String: Any] = [
            "id": log.id.uuidString,
            "url": log.url?.absoluteString ?? "",
            "method": log.method,
            "startedAt": DateFormatter.prowlTimestamp.string(from: log.startedAt),
            "duration": log.duration,
            "requestHeaders": log.requestHeaders,
            "responseHeaders": log.responseHeaders,
        ]

        if let code = log.statusCode { dict["statusCode"] = code } else { dict["error"] = log.errorDescription ?? "" }

        if let req = log.requestBody {
            dict["requestBody"] = (try? JSONSerialization.jsonObject(with: req.data))
                ?? (String(data: req.data, encoding: .utf8) ?? "")
        }

        if let res = log.responseBody {
            dict["responseBody"] = (try? JSONSerialization.jsonObject(with: res.data))
                ?? (String(data: res.data, encoding: .utf8) ?? "")
        }

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }
}

private extension DateFormatter {
    static let prowlTimestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()
}
