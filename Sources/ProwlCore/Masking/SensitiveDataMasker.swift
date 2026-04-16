import Foundation

public struct SensitiveDataMasker: Sendable {
    public let sensitiveHeaders: Set<String>
    public let sensitiveJSONKeys: Set<String>
    public let redactionToken: String

    public init(
        sensitiveHeaders: Set<String> = ["authorization", "cookie"],
        sensitiveJSONKeys: Set<String> = ["password", "token"],
        redactionToken: String = "[REDACTED]"
    ) {
        self.sensitiveHeaders = Set(sensitiveHeaders.map { $0.lowercased() })
        self.sensitiveJSONKeys = Set(sensitiveJSONKeys.map { $0.lowercased() })
        self.redactionToken = redactionToken
    }

    public func mask(headers: [String: String]) -> [String: String] {
        var masked: [String: String] = [:]
        masked.reserveCapacity(headers.count)

        for (key, value) in headers {
            masked[key] = sensitiveHeaders.contains(key.lowercased()) ? redactionToken : value
        }
        return masked
    }

    public func mask(body data: Data?, contentType: String?) -> NetworkLog.Body? {
        guard let data else { return nil }
        guard let contentType, contentType.lowercased().contains("application/json") else {
            return .init(data: data, contentType: contentType)
        }

        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let maskedObject = mask(json: object),
            JSONSerialization.isValidJSONObject(maskedObject),
            let maskedData = try? JSONSerialization.data(withJSONObject: maskedObject, options: [.prettyPrinted, .sortedKeys])
        else {
            return .init(data: data, contentType: contentType)
        }

        return .init(data: maskedData, contentType: contentType)
    }

    private func mask(json value: Any) -> Any? {
        switch value {
        case let dictionary as [String: Any]:
            var output: [String: Any] = [:]
            output.reserveCapacity(dictionary.count)
            for (key, nestedValue) in dictionary {
                if sensitiveJSONKeys.contains(key.lowercased()) {
                    output[key] = redactionToken
                } else if let maskedNested = mask(json: nestedValue) {
                    output[key] = maskedNested
                }
            }
            return output
        case let array as [Any]:
            return array.compactMap(mask(json:))
        case let number as NSNumber:
            return number
        case let string as String:
            return string
        case _ as NSNull:
            return NSNull()
        default:
            return nil
        }
    }
}
