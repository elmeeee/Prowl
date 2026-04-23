import Foundation

public actor ProwlRuntime {
    public static let shared = ProwlRuntime()
    
    nonisolated(unsafe) public static var ignoredURLs: Set<String> = []
    nonisolated(unsafe) public static var ignoredURLRegexes: Set<String> = []
    nonisolated(unsafe) public static var customSessionDelegate: URLSessionDelegate? = nil
    nonisolated(unsafe) public static var isLoggingEnabled: Bool = true
    nonisolated(unsafe) public static var isSensitiveDataMaskingEnabled: Bool = false

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
        isLoggingEnabled: Bool? = nil,
        isSensitiveDataMaskingEnabled: Bool? = nil
    ) {
        if let storage {
            self.storage = storage
        }
        if let masker {
            self.masker = masker
        }
        if let isLoggingEnabled {
            Self.isLoggingEnabled = isLoggingEnabled
        }
        if let isSensitiveDataMaskingEnabled {
            Self.isSensitiveDataMaskingEnabled = isSensitiveDataMaskingEnabled
        }
    }

    public nonisolated static func shouldIgnore(_ absoluteURLString: String) -> Bool {
        if ignoredURLs.contains(where: { absoluteURLString.contains($0) }) {
            return true
        }

        for pattern in ignoredURLRegexes {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }
            let range = NSRange(location: 0, length: absoluteURLString.utf16.count)
            if regex.firstMatch(in: absoluteURLString, options: [], range: range) != nil {
                return true
            }
        }

        return false
    }

    public nonisolated static func installRequestBodySnapshotSupportIfNeeded() {
        #if canImport(ObjectiveC)
        ProwlURLSessionBodySnapshotInstaller.installIfNeeded()
        #endif
    }

    public func snapshot() -> (storage: ProwlStorage, masker: SensitiveDataMasker) {
        (storage, masker)
    }

    public func currentStorage() -> ProwlStorage {
        storage
    }
}
