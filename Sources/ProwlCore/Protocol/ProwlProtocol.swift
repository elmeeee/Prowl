import Foundation

public final class ProwlProtocol: URLProtocol, @unchecked Sendable {
    private static let handledKey = "com.prowl.handled"
    private static let requestIDKey = "com.prowl.requestID"

    private var session: URLSession?
    private var dataTask: URLSessionDataTask?

    override public class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return false
        }

        if let isHandled = URLProtocol.property(forKey: handledKey, in: request) as? Bool, isHandled {
            return false
        }

        return true
    }

    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override public func startLoading() {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)
        URLProtocol.setProperty(UUID().uuidString, forKey: Self.requestIDKey, in: mutableRequest)

        let proxiedRequest = mutableRequest as URLRequest
        let startedAt = Date()

        let config = URLSessionConfiguration.default
        config.protocolClasses = (config.protocolClasses ?? []).filter { $0 != ProwlProtocol.self }

        session = URLSession(configuration: config)
        dataTask = session?.dataTask(with: proxiedRequest) { [weak self] data, response, error in
            guard let self else { return }
            self.complete(
                request: proxiedRequest,
                startedAt: startedAt,
                data: data ?? Data(),
                response: response,
                error: error
            )
        }
        dataTask?.resume()
    }

    override public func stopLoading() {
        dataTask?.cancel()
        session?.invalidateAndCancel()
        dataTask = nil
        session = nil
    }
    
    private func complete(
        request: URLRequest,
        startedAt: Date,
        data: Data,
        response: URLResponse?,
        error: Error?
    ) {
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: data)
        if let error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }

        let duration = Date().timeIntervalSince(startedAt)
        let requestHeaders = request.allHTTPHeaderFields ?? [:]
        let responseHeaders = (response as? HTTPURLResponse)?
            .allHeaderFields
            .reduce(into: [String: String]()) { partialResult, pair in
                guard let key = pair.key as? String else { return }
                partialResult[key] = String(describing: pair.value)
            } ?? [:]

        let requestID = (URLProtocol.property(forKey: Self.requestIDKey, in: request) as? String)
            .flatMap(UUID.init(uuidString:))
            ?? UUID()

        Task {
            let runtime = ProwlRuntime.shared
            let snapshot = await runtime.snapshot()
            let requestBody = snapshot.masker.mask(
                body: request.httpBody,
                contentType: request.value(forHTTPHeaderField: "Content-Type")
            )
            let responseBody = snapshot.masker.mask(
                body: data,
                contentType: (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")
            )

            let log = NetworkLog(
                requestID: requestID,
                url: request.url,
                method: request.httpMethod ?? "GET",
                requestHeaders: snapshot.masker.mask(headers: requestHeaders),
                requestBody: requestBody,
                responseHeaders: snapshot.masker.mask(headers: responseHeaders),
                responseBody: responseBody,
                statusCode: (response as? HTTPURLResponse)?.statusCode,
                startedAt: startedAt,
                duration: duration,
                errorDescription: error?.localizedDescription
            )
            
            let statusStr = log.statusCode.map { "\($0)" } ?? "ERR"
            let hostStr = log.url?.host ?? ""
            let pathStr = log.url?.path.isEmpty == false ? (log.url?.path ?? "/") : "/"
            print("🐾 [Prowl] \(log.method) \(statusStr) \(hostStr)\(pathStr) (\(String(format: "%.3fs", log.duration)))")

            await snapshot.storage.append(log)
        }
    }
}
