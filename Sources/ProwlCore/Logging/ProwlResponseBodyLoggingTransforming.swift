import Foundation

/// Optional hook to rewrite **logged** response bytes (for example decrypting a custom payload) before masking and storage.
/// Does not change bytes delivered to your app’s `URLSession` completion handler.
public protocol ProwlResponseBodyLoggingTransforming: AnyObject, Sendable {
    func responseBodyForLogging(
        data: Data,
        contentType: String?,
        url: URL?,
        statusCode: Int?
    ) -> Data?
}
