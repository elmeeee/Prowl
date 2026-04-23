import Foundation

public extension URLSession {
    /// Creates a data task after attaching a safe Prowl body snapshot.
    func prowlDataTask(
        with request: URLRequest,
        bodySnapshot: Data?
    ) -> URLSessionDataTask {
        let capturedRequest = prowlRequestWithSnapshot(from: request, bodySnapshot: bodySnapshot)
        return dataTask(with: capturedRequest)
    }

    /// Creates a data task with completion after attaching a safe Prowl body snapshot.
    func prowlDataTask(
        with request: URLRequest,
        bodySnapshot: Data?,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        let capturedRequest = prowlRequestWithSnapshot(from: request, bodySnapshot: bodySnapshot)
        return dataTask(with: capturedRequest, completionHandler: completionHandler)
    }

    /// Creates a streamed upload task while attaching a safe Prowl body snapshot.
    func prowlUploadTask(
        withStreamedRequest request: URLRequest,
        bodySnapshot: Data
    ) -> URLSessionUploadTask {
        let capturedRequest = prowlRequestWithSnapshot(from: request, bodySnapshot: bodySnapshot)
        return uploadTask(withStreamedRequest: capturedRequest)
    }

    private func prowlRequestWithSnapshot(from request: URLRequest, bodySnapshot: Data?) -> URLRequest {
        guard let bodySnapshot, !bodySnapshot.isEmpty else {
            return request
        }
        if ProwlRequestBodySnapshot.body(from: request) != nil {
            return request
        }
        return request.withProwlBodySnapshot(bodySnapshot)
    }
}
