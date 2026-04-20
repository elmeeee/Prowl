//
//  ProwlMocker.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import Foundation

public struct ProwlMockRule: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var targetURLPattern: String
    public var targetMethod: String
    
    public var mockStatusCode: Int
    public var mockBody: Data
    public var mockHeaders: [String: String]
    
    public var isEnabled: Bool
    
    public init(
        id: UUID = UUID(),
        targetURLPattern: String,
        targetMethod: String = "ANY",
        mockStatusCode: Int = 200,
        mockBody: Data = Data(),
        mockHeaders: [String : String] = ["Content-Type": "application/json"],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.targetURLPattern = targetURLPattern
        self.targetMethod = targetMethod
        self.mockStatusCode = mockStatusCode
        self.mockBody = mockBody
        self.mockHeaders = mockHeaders
        self.isEnabled = isEnabled
    }
}

public actor ProwlMocker {
    public static let shared = ProwlMocker()
    
    private var rules: [ProwlMockRule] = []
    
    public func addRule(_ rule: ProwlMockRule) {
        rules.append(rule)
    }
    
    public func updateRule(_ rule: ProwlMockRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        }
    }
    
    public func removeRule(id: UUID) {
        rules.removeAll(where: { $0.id == id })
    }
    
    public func allRules() -> [ProwlMockRule] {
        return rules
    }
    
    public func findMatch(for request: URLRequest) -> ProwlMockRule? {
        guard let urlStr = request.url?.absoluteString else { return nil }
        let method = request.httpMethod ?? "GET"
        
        return rules.first { rule in
            guard rule.isEnabled, !rule.targetURLPattern.isEmpty else { return false }
            guard urlStr.lowercased().contains(rule.targetURLPattern.lowercased()) else { return false }
            
            if !rule.targetMethod.isEmpty && rule.targetMethod.uppercased() != "ANY" {
                guard method.uppercased() == rule.targetMethod.uppercased() else { return false }
            }
            return true
        }
    }
}
