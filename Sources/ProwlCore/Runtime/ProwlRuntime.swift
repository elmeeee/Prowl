import Foundation

public actor ProwlRuntime {
    public static let shared = ProwlRuntime()
    
    nonisolated(unsafe) public static var ignoredURLs: Set<String> = []

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
        masker: SensitiveDataMasker? = nil
    ) {
        if let storage {
            self.storage = storage
        }
        if let masker {
            self.masker = masker
        }
    }

    public func snapshot() -> (storage: ProwlStorage, masker: SensitiveDataMasker) {
        (storage, masker)
    }

    public func currentStorage() -> ProwlStorage {
        storage
    }
}
