//
//  ProwlMockEditorViewModel.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2025 Elmee. All rights reserved.
//

import Foundation
import ProwlCore

public enum ProwlMockEditorIntent {
    case save(urlPattern: String, statusCodeStr: String, bodyJSON: String)
    case cancel
}

@MainActor
public final class ProwlMockEditorViewModel: ObservableObject {

    public let initialURLPattern: String
    public let initialBodyJSON: String

    @Published public private(set) var isSaved = false

    public init(log: NetworkLog) {
        initialURLPattern = log.url?.absoluteString ?? ""

        var defaultBody = #"{ "message": "Mocked via Prowl" }"#
        if let body = log.responseBody,
           let text = String(data: body.data, encoding: .utf8) {
            defaultBody = text
        }
        initialBodyJSON = defaultBody
    }

    public func handle(_ intent: ProwlMockEditorIntent) {
        switch intent {
        case let .save(urlPattern, statusCodeStr, bodyJSON):
            save(urlPattern: urlPattern, statusCodeStr: statusCodeStr, bodyJSON: bodyJSON)
        case .cancel:
            break
        }
    }

    private func save(urlPattern: String, statusCodeStr: String, bodyJSON: String) {
        let code = Int(statusCodeStr) ?? 200
        let data = bodyJSON.data(using: .utf8) ?? Data()

        let rule = ProwlMockRule(
            targetURLPattern: urlPattern,
            targetMethod: "ANY",
            mockStatusCode: code,
            mockBody: data,
            isEnabled: true
        )

        Task {
            await ProwlMocker.shared.addRule(rule)
            isSaved = true
        }
    }
}
