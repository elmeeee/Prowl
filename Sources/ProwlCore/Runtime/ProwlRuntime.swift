import Foundation

public enum ProwlRequestBodyCaptureMode: Sendable {
    /// Does not touch outbound request payload. Captures stream body only from stream copies.
    case safeBestEffort
    /// Allows consuming and rebuilding non-copyable body streams for logging.
    /// Use only when full payload visibility is more important than strict non-intrusive behavior.
    case aggressiveStreamReplay
}

public actor ProwlRuntime {
    public static let shared = ProwlRuntime()
    
    nonisolated(unsafe) public static var ignoredURLs: Set<String> = []
    nonisolated(unsafe) public static var customSessionDelegate: URLSessionDelegate? = nil
    nonisolated(unsafe) public static var requestBodyCaptureMode: ProwlRequestBodyCaptureMode = .safeBestEffort

    private var storage: ProwlStorage
    private var masker: SensitiveDataMasker

    public init(
        storage: ProwlStorage = .init(),
        masker: SensitiveDataMasker = .init()
    ) {
        self.storage = storage
        self.masker = masker
    }

    public func configure(
        storage: ProwlStorage? = nil,
        masker: SensitiveDataMasker? = nil,
        requestBodyCaptureMode: ProwlRequestBodyCaptureMode? = nil
    ) {
        if let storage {
            self.storage = storage
        }
        if let masker {
            self.masker = masker
        }
        if let requestBodyCaptureMode {
            Self.requestBodyCaptureMode = requestBodyCaptureMode
        }
    }

    public func snapshot() -> (storage: ProwlStorage, masker: SensitiveDataMasker) {
        (storage, masker)
    }

    public func currentStorage() -> ProwlStorage {
        storage
    }
}
