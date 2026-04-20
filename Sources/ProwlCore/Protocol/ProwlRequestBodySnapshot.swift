import Foundation

public enum ProwlRequestBodySnapshot {
    static let key = "com.prowl.requestBodySnapshot"

    /// Attaches a request body snapshot as URLProtocol metadata.
    /// This does not alter the outgoing transport payload.
    public static func attach(_ body: Data, to request: inout URLRequest) {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return
        }
        URLProtocol.setProperty(body, forKey: key, in: mutableRequest)
        request = mutableRequest as URLRequest
    }

    public static func body(from request: URLRequest) -> Data? {
        URLProtocol.property(forKey: key, in: request) as? Data
    }
}

public extension URLRequest {
    mutating func attachProwlBodySnapshot(_ body: Data) {
        ProwlRequestBodySnapshot.attach(body, to: &self)
    }

    func withProwlBodySnapshot(_ body: Data) -> URLRequest {
        var copy = self
        copy.attachProwlBodySnapshot(body)
        return copy
    }
}
