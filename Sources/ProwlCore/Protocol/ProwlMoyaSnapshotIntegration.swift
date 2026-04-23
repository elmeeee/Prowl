import Foundation

#if canImport(Moya)
import Moya

/// Moya plugin that preserves request-body snapshots for Prowl logging.
public struct ProwlMoyaBodySnapshotPlugin: PluginType {
    public init() {}

    public func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        if let existing = ProwlRequestBodySnapshot.body(from: request), !existing.isEmpty {
            return request
        }

        if let requestBody = request.httpBody, !requestBody.isEmpty {
            return request.withProwlBodySnapshot(requestBody)
        }

        guard let taskBody = bodyData(from: target.task), !taskBody.isEmpty else {
            return request
        }
        return request.withProwlBodySnapshot(taskBody)
    }

    private func bodyData(from task: Task) -> Data? {
        switch task {
        case let .requestData(data):
            return data
        case let .requestCompositeData(data, _):
            return data
        default:
            return nil
        }
    }
}
#endif
