import Flutter
import UIKit
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Brücke zwischen Flutter und der Live Activity (iOS).
public class WashLivePlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var launch: [String: String]?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "wash/live", binaryMessenger: registrar.messenger())
        let instance = WashLivePlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "start":
            if #available(iOS 16.2, *) {
                LiveActivities.start(args)
            }
            result(nil)
        case "stop":
            if #available(iOS 16.2, *) {
                LiveActivities.stop(machine: args["machine"] as? String ?? "")
            }
            result(nil)
        case "launchAction":
            result(launch)
            launch = nil
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: Tipps auf die Live Activity (wash://open?machine=…&action=…)

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [AnyHashable: Any] = [:]
    ) -> Bool {
        if let url = launchOptions[UIApplication.LaunchOptionsKey.url] as? URL {
            launch = Self.parse(url)
        }
        return true
    }

    public func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        guard let data = Self.parse(url) else { return false }
        if let channel = channel {
            channel.invokeMethod("open", arguments: data)
        } else {
            launch = data
        }
        return true
    }

    static func parse(_ url: URL) -> [String: String]? {
        guard url.scheme == "wash",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let machine = items.first(where: { $0.name == "machine" })?.value
        else { return nil }
        var data = ["machine": machine]
        if let action = items.first(where: { $0.name == "action" })?.value {
            data["action"] = action
        }
        return data
    }
}

#if canImport(ActivityKit)
@available(iOS 16.2, *)
enum LiveActivities {
    static func start(_ a: [String: Any]) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              let machine = a["machine"] as? String,
              let title = a["title"] as? String,
              let program = a["program"] as? String,
              let startMs = (a["start"] as? NSNumber)?.doubleValue,
              let endMs = (a["end"] as? NSNumber)?.doubleValue
        else { return }

        let start = Date(timeIntervalSince1970: startMs / 1000)
        let end = Date(timeIntervalSince1970: endMs / 1000)
        stop(machine: machine)

        let state = WashLiveAttributes.ContentState(title: title, program: program, start: start, end: end)
        do {
            _ = try Activity.request(
                attributes: WashLiveAttributes(machine: machine),
                content: ActivityContent(state: state, staleDate: end),
                pushType: nil
            )
        } catch {
            NSLog("WashLive: Live Activity nicht gestartet: \(error)")
        }
    }

    static func stop(machine: String) {
        for activity in Activity<WashLiveAttributes>.activities where activity.attributes.machine == machine {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
#endif
