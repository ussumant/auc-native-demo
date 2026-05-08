import Foundation

struct AUCDemoReleaseConfig: Decodable, Sendable {
    var profile: String
    var seededOpenAIAPIKey: String?
    var releaseVersion: String?

    var isOpenAIDemo: Bool {
        profile == "openai-demo"
    }

    static let empty = AUCDemoReleaseConfig(profile: "full", seededOpenAIAPIKey: nil, releaseVersion: nil)

    static func load(bundle: Bundle = .main) -> AUCDemoReleaseConfig {
        guard let url = bundle.url(forResource: "DemoReleaseConfig", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(AUCDemoReleaseConfig.self, from: data) else {
            return .empty
        }
        return config
    }
}
