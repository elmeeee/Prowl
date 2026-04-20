import Foundation

enum ProwlRequestReplaySafety {
    static func isAggressiveReplaySafe(for request: URLRequest) -> Bool {
        guard request.httpBodyStream != nil else {
            return false
        }

        let transferEncoding = request.value(forHTTPHeaderField: "Transfer-Encoding")?.lowercased() ?? ""
        if transferEncoding.contains("chunked") {
            return false
        }

        let contentType = request.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        if contentType.contains("multipart/form-data") {
            return false
        }

        let expectHeader = request.value(forHTTPHeaderField: "Expect")?.lowercased() ?? ""
        if expectHeader.contains("100-continue") {
            return false
        }

        return true
    }
}
