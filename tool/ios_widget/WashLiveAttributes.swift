// Diese Datei existiert zweimal: im Plugin (startet die Live Activity) und in
// der Widget-Erweiterung (zeichnet sie). Beide Kopien müssen identisch sein –
// iOS ordnet die Activity über den Namen „WashLiveAttributes“ zu.

#if canImport(ActivityKit)
import ActivityKit
import Foundation

@available(iOS 16.1, *)
public struct WashLiveAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var title: String
        public var program: String
        public var start: Date
        public var end: Date

        public init(title: String, program: String, start: Date, end: Date) {
            self.title = title
            self.program = program
            self.start = start
            self.end = end
        }
    }

    /// "wash" oder "dry"
    public var machine: String

    public init(machine: String) {
        self.machine = machine
    }
}
#endif
