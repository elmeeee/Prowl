import Foundation

#if canImport(ObjectiveC)
import ObjectiveC.runtime

enum ProwlURLSessionBodySnapshotInstaller {
    private static let installOnce: Void = {
        swizzleUploadTaskWithoutCompletion()
        swizzleUploadTaskWithCompletion()
    }()

    static func installIfNeeded() {
        _ = installOnce
    }

    private static func swizzleUploadTaskWithoutCompletion() {
        let originalSelector = #selector(URLSession.uploadTask(with:from:))
        let swizzledSelector = #selector(URLSession.prowl_uploadTask(with:from:))
        swizzleInstanceMethod(
            on: URLSession.self,
            originalSelector: originalSelector,
            swizzledSelector: swizzledSelector
        )
    }

    private static func swizzleUploadTaskWithCompletion() {
        let originalSelector = #selector(URLSession.uploadTask(with:from:completionHandler:))
        let swizzledSelector = #selector(URLSession.prowl_uploadTask(with:from:completionHandler:))
        swizzleInstanceMethod(
            on: URLSession.self,
            originalSelector: originalSelector,
            swizzledSelector: swizzledSelector
        )
    }

    private static func swizzleInstanceMethod(
        on cls: AnyClass,
        originalSelector: Selector,
        swizzledSelector: Selector
    ) {
        guard
            let originalMethod = class_getInstanceMethod(cls, originalSelector),
            let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector)
        else {
            return
        }

        let didAdd = class_addMethod(
            cls,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )

        if didAdd {
            class_replaceMethod(
                cls,
                swizzledSelector,
                method_getImplementation(originalMethod),
                method_getTypeEncoding(originalMethod)
            )
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
}

private extension URLSession {
    func prowl_requestByAttachingBodySnapshot(
        _ request: URLRequest,
        bodyData: Data?
    ) -> URLRequest {
        guard let bodyData, !bodyData.isEmpty else {
            return request
        }
        if ProwlRequestBodySnapshot.body(from: request) != nil {
            return request
        }
        return request.withProwlBodySnapshot(bodyData)
    }

    @objc
    func prowl_uploadTask(with request: URLRequest, from bodyData: Data?) -> URLSessionUploadTask {
        let capturedRequest = prowl_requestByAttachingBodySnapshot(request, bodyData: bodyData)
        return prowl_uploadTask(with: capturedRequest, from: bodyData)
    }

    @objc
    func prowl_uploadTask(
        with request: URLRequest,
        from bodyData: Data?,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionUploadTask {
        let capturedRequest = prowl_requestByAttachingBodySnapshot(request, bodyData: bodyData)
        return prowl_uploadTask(with: capturedRequest, from: bodyData, completionHandler: completionHandler)
    }
}
#endif
