import Foundation

public final class ProwlProtocol: URLProtocol, @unchecked Sendable {
    private static let handledKey = "com.prowl.handled"
    private static let requestIDKey = "com.prowl.requestID"

    private var session: URLSession?
    private var dataTask: URLSessionDataTask?

    override public class func canInit(with request: URLRequest) -> Bool {
        guard ProwlRuntime.isLoggingEnabled else {
            return false
        }

        guard let scheme = request.url?.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return false
        }

        if let isHandled = URLProtocol.property(forKey: handledKey, in: request) as? Bool, isHandled {
            return false
        }
        
        if let absoluteString = request.url?.absoluteString,
           ProwlRuntime.shouldIgnore(absoluteString) {
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

        let requestBodyData = Self.captureRequestBody(
            from: request,
            mutableRequest: mutableRequest,
            mode: ProwlRuntime.requestBodyCaptureMode
        )

        let proxiedRequest = mutableRequest as URLRequest
        let startedAt = Date()

        let config = URLSessionConfiguration.default
        config.protocolClasses = (config.protocolClasses ?? []).filter { $0 != ProwlProtocol.self }

        Task {
            if let mockRule = await ProwlMocker.shared.findMatch(for: proxiedRequest) {
                // Return MOCK!
                let mockURL = proxiedRequest.url ?? URL(string: "https://prowl.mock")!
                let mockResponse = HTTPURLResponse(url: mockURL, statusCode: mockRule.mockStatusCode, httpVersion: "HTTP/1.1", headerFields: mockRule.mockHeaders)
                
                self.complete(
                    request: proxiedRequest,
                    requestBodyData: requestBodyData,
                    startedAt: startedAt,
                    data: mockRule.mockBody,
                    response: mockResponse,
                    error: nil
                )
                return
            }
            
            // Proceed normally if no mock
            self.session = URLSession(configuration: config, delegate: ProwlRuntime.customSessionDelegate, delegateQueue: nil)
            self.dataTask = self.session?.dataTask(with: proxiedRequest) { [weak self] data, response, error in
                guard let self else { return }
                self.complete(
                    request: proxiedRequest,
                    requestBodyData: requestBodyData,
                    startedAt: startedAt,
                    data: data ?? Data(),
                    response: response,
                    error: error
                )
            }
            self.dataTask?.resume()
        }
    }

    override public func stopLoading() {
        dataTask?.cancel()
        session?.invalidateAndCancel()
        dataTask = nil
        session = nil
    }
    
    private func complete(
        request: URLRequest,
        requestBodyData: Data?,
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
        let requestURL = request.url
        let requestMethod = request.httpMethod ?? "GET"
        let requestContentType = request.value(forHTTPHeaderField: "Content-Type")
        let responseContentType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        let timeoutInterval = request.timeoutInterval
        let cachePolicy = Self.cachePolicyName(request.cachePolicy)
        let errorDescription = error?.localizedDescription

        Task {
            let runtime = ProwlRuntime.shared
            let snapshot = await runtime.snapshot()
            let requestBody = snapshot.masker.mask(
                body: requestBodyData ?? request.httpBody,
                contentType: requestContentType
            )
            let responseBody = snapshot.masker.mask(
                body: data,
                contentType: responseContentType
            )

            let log = NetworkLog(
                requestID: requestID,
                url: requestURL,
                method: requestMethod,
                requestHeaders: snapshot.masker.mask(headers: requestHeaders),
                requestBody: requestBody,
                responseHeaders: snapshot.masker.mask(headers: responseHeaders),
                responseBody: responseBody,
                statusCode: statusCode,
                startedAt: startedAt,
                duration: duration,
                timeoutInterval: timeoutInterval,
                cachePolicy: cachePolicy,
                errorDescription: errorDescription
            )
            
            await snapshot.storage.append(log)
        }
    }

    /// Captures request body without mutating the outbound request payload.
    /// For stream-backed bodies, we only read from a copied stream when available.
    private static func captureRequestBodyBestEffort(from request: URLRequest) -> Data? {
        if let body = request.httpBody, !body.isEmpty {
            return body
        }

        guard
            let stream = request.httpBodyStream,
            let copyable = stream as? NSCopying,
            let copiedStream = copyable.copy(with: nil) as? InputStream
        else {
            return nil
        }

        return readAllBytes(from: copiedStream)
    }

    private static func captureRequestBody(
        from request: URLRequest,
        mutableRequest: NSMutableURLRequest,
        mode: ProwlRequestBodyCaptureMode
    ) -> Data? {
        if let bestEffort = captureRequestBodyBestEffort(from: request) {
            return bestEffort
        }

        if let snapshotBody = ProwlRequestBodySnapshot.body(from: request), !snapshotBody.isEmpty {
            return snapshotBody
        }

        guard mode == .aggressiveStreamReplay else {
            return nil
        }
        guard ProwlRequestReplaySafety.isAggressiveReplaySafe(for: request) else {
            return nil
        }

        return replayBodyStreamFromOriginalRequest(into: mutableRequest)
    }

    private static func replayBodyStreamFromOriginalRequest(into mutableRequest: NSMutableURLRequest) -> Data? {
        guard let originalStream = mutableRequest.httpBodyStream else {
            return nil
        }
        guard let captured = readAllBytes(from: originalStream), !captured.isEmpty else {
            return nil
        }

        // Rebuild outbound payload from captured bytes after consuming original stream.
        // Keep framing headers consistent with the new body representation.
        mutableRequest.httpBody = captured
        mutableRequest.httpBodyStream = nil
        mutableRequest.setValue(String(captured.count), forHTTPHeaderField: "Content-Length")
        mutableRequest.setValue(nil, forHTTPHeaderField: "Transfer-Encoding")
        return captured
    }

    private static func readAllBytes(from stream: InputStream) -> Data? {
        var captured = Data()
        stream.open()
        defer { stream.close() }

        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while stream.hasBytesAvailable {
            let readCount = stream.read(&buffer, maxLength: bufferSize)
            if readCount < 0 {
                return nil
            }
            if readCount == 0 {
                break
            }
            captured.append(buffer, count: readCount)
        }

        return captured.isEmpty ? nil : captured
    }

    private static func cachePolicyName(_ policy: URLRequest.CachePolicy) -> String {
        switch policy {
        case .useProtocolCachePolicy:
            return "UseProtocolCachePolicy"
        case .reloadIgnoringLocalCacheData:
            return "ReloadIgnoringLocalCacheData"
        case .reloadIgnoringLocalAndRemoteCacheData:
            return "ReloadIgnoringLocalAndRemoteCacheData"
        case .returnCacheDataElseLoad:
            return "ReturnCacheDataElseLoad"
        case .returnCacheDataDontLoad:
            return "ReturnCacheDataDontLoad"
        case .reloadRevalidatingCacheData:
            return "ReloadRevalidatingCacheData"
        @unknown default:
            return String(describing: policy)
        }
    }
}
