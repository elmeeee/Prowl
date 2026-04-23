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

    /// Configures a stream-backed body while preserving a safe logging snapshot.
    /// This keeps transport behavior stream-based and does not consume the stream.
    mutating func setProwlHTTPBodyStream(_ body: Data) {
        httpBody = nil
        httpBodyStream = InputStream(data: body)
        attachProwlBodySnapshot(body)
    }

    /// Returns a request copy configured with stream body + Prowl snapshot.
    func withProwlHTTPBodyStream(_ body: Data) -> URLRequest {
        var copy = self
        copy.setProwlHTTPBodyStream(body)
        return copy
    }

    /// Attaches JSON-encoded snapshot to support non-intrusive request body logging.
    @discardableResult
    mutating func attachProwlJSONBodySnapshot<T: Encodable>(
        _ value: T,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> Data {
        let data = try encoder.encode(value)
        attachProwlBodySnapshot(data)
        return data
    }
}
