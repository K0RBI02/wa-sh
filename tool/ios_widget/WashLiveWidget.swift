// Widget-Erweiterung für wa:sh: zeichnet die Live Activity auf dem
// Sperrbildschirm und in der Dynamic Island. Countdown und Balken zählt iOS
// selbst weiter – die App muss dafür nicht laufen.
//
// Einrichtung: siehe README → „iOS: Live Activity einrichten“.

import ActivityKit
import SwiftUI
import WidgetKit

/// Deutsch, wenn die bevorzugte Sprache Deutsch ist – sonst Englisch.
func tr(_ de: String, _ en: String) -> String {
    (Locale.preferredLanguages.first ?? "en").hasPrefix("de") ? de : en
}

@main
struct WashLiveBundle: WidgetBundle {
    var body: some Widget {
        WashLiveActivity()
    }
}

private let ink = Color(red: 0x21 / 255, green: 0x25 / 255, blue: 0x29 / 255)
private let pink = Color(red: 0xF7 / 255, green: 0xD6 / 255, blue: 0xD2 / 255)
private let peach = Color(red: 0xFC / 255, green: 0xE3 / 255, blue: 0xCF / 255)

private func tint(_ machine: String) -> Color { machine == "wash" ? pink : peach }
private func symbol(_ machine: String) -> String { machine == "wash" ? "washer" : "dryer" }

private func link(_ machine: String, _ action: String?) -> URL {
    var s = "wash://open?machine=\(machine)"
    if let action { s += "&action=\(action)" }
    return URL(string: s)!
}

struct WashLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WashLiveAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(tint(context.attributes.machine))
                .activitySystemActionForegroundColor(ink)
                .widgetURL(link(context.attributes.machine, nil))
        } dynamicIsland: { context in
            let m = context.attributes.machine
            let range = context.state.start...max(context.state.start, context.state.end)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.title, systemImage: symbol(m))
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: range, countsDown: true)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        ProgressView(timerInterval: range, countsDown: false) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(tint(m))
                        ActionRow(machine: m, light: true)
                    }
                }
            } compactLeading: {
                Image(systemName: symbol(m))
            } compactTrailing: {
                Text(timerInterval: range, countsDown: true)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: symbol(m))
            }
            .widgetURL(link(m, nil))
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<WashLiveAttributes>

    var body: some View {
        let m = context.attributes.machine
        let range = context.state.start...max(context.state.start, context.state.end)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(context.state.title, systemImage: symbol(m))
                    .font(.headline)
                Spacer()
                Text(timerInterval: range, countsDown: true)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
            }
            ProgressView(timerInterval: range, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(ink)
            Text("\(tr("Fertig um", "Done at")) \(context.state.end, style: .time) · \(context.state.program)")
                .font(.subheadline)
                .foregroundStyle(ink.opacity(0.75))
            ActionRow(machine: m, light: false)
        }
        .foregroundStyle(ink)
        .padding(16)
    }
}

private struct ActionRow: View {
    let machine: String
    let light: Bool

    var body: some View {
        HStack(spacing: 8) {
            Link(destination: link(machine, "finish")) { pill(tr("Schon fertig", "Already done")) }
            Link(destination: link(machine, "overview")) { pill(tr("Zur Übersicht", "Overview")) }
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(light ? Color.white.opacity(0.18) : Color.white.opacity(0.55), in: Capsule())
    }
}
