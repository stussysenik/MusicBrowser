import Foundation

enum AppRuntime: Equatable {
    case live
    case dummy

    static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
    }

    static var current: AppRuntime {
        let processInfo = ProcessInfo.processInfo
        return resolve(
            arguments: Set(processInfo.arguments),
            environment: processInfo.environment,
            isRunningTests: isRunningTests,
            prefersDummyData: defaultPrefersDummyData
        )
    }

    static func resolve(
        arguments: Set<String>,
        environment: [String: String],
        isRunningTests: Bool,
        prefersDummyData: Bool
    ) -> AppRuntime {
        if isRunningTests {
            return .dummy
        }

        if arguments.contains("-demo-mode")
            || arguments.contains("demo-mode")
            || arguments.contains("-ui-testing")
            || environment["UI_TEST_MODE"] == "1" {
            return .dummy
        }

        if arguments.contains("-live-mode") || environment["LIVE_MUSIC_MODE"] == "1" {
            return .live
        }

        return prefersDummyData ? .dummy : .live
    }

    private static var defaultPrefersDummyData: Bool {
        #if DEBUG && os(iOS)
        return true
        #else
        return false
        #endif
    }

    var usesDummyData: Bool {
        self == .dummy
    }

    var requiresMusicAuthorization: Bool {
        !usesDummyData
    }

    var storeURL: URL? {
        guard usesDummyData else { return nil }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return appSupport?.appendingPathComponent("MusicBrowser-Dummy.store")
    }
}
