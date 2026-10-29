import SwiftUI
import WidgetKit

private let widgetGroup = "group.it.billnice.apps.dokploy"

struct InfrastructureEntry: TimelineEntry {
  let date: Date
  let instanceName: String
  let running: Int
  let stopped: Int
  let failed: Int

  static let placeholder = InfrastructureEntry(
    date: .now,
    instanceName: "Demo Infrastructure",
    running: 12,
    stopped: 2,
    failed: 1
  )
}

struct InfrastructureProvider: TimelineProvider {
  func placeholder(in context: Context) -> InfrastructureEntry {
    .placeholder
  }

  func getSnapshot(in context: Context, completion: @escaping (InfrastructureEntry) -> Void) {
    completion(readEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<InfrastructureEntry>) -> Void) {
    let entry = readEntry()
    completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 60))))
  }

  private func readEntry() -> InfrastructureEntry {
    let defaults = UserDefaults(suiteName: widgetGroup)
    return InfrastructureEntry(
      date: .now,
      instanceName: defaults?.string(forKey: "instanceName") ?? "Open DployGo to refresh",
      running: defaults?.integer(forKey: "running") ?? 0,
      stopped: defaults?.integer(forKey: "stopped") ?? 0,
      failed: defaults?.integer(forKey: "failed") ?? 0
    )
  }
}

struct InfrastructureWidgetView: View {
  let entry: InfrastructureEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 7) {
        Image(systemName: "water.waves")
          .foregroundStyle(.white)
        Text("DPLOYGO")
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .tracking(1.2)
          .foregroundStyle(.white.opacity(0.68))
        Spacer(minLength: 2)
        Image(systemName: entry.failed > 0 ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
          .foregroundStyle(entry.failed > 0 ? Color.orange : Color.green)
      }
      Text(entry.instanceName)
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .lineLimit(1)
        .foregroundStyle(.white)
      HStack(alignment: .firstTextBaseline, spacing: 0) {
        metric(entry.running, label: "RUNNING", color: .green)
        Spacer(minLength: 4)
        metric(entry.stopped, label: "STOPPED", color: .orange)
        Spacer(minLength: 4)
        metric(entry.failed, label: "FAILED", color: .red)
      }
      if family != .systemSmall {
        Text("Tap to open DployGo")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.white.opacity(0.55))
      }
    }
    .padding(16)
    .background(Color(red: 0.08, green: 0.08, blue: 0.10))
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .widgetURL(URL(string: "dokploy-mobile://app"))
  }

  private func metric(_ value: Int, label: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("\(value)")
        .font(.system(size: 24, weight: .bold, design: .rounded))
        .foregroundStyle(color)
      Text(label)
        .font(.system(size: 8, weight: .bold, design: .rounded))
        .tracking(0.4)
        .foregroundStyle(.white.opacity(0.62))
    }
  }
}

@main
struct DployGoStatusWidget: Widget {
  let kind = "DployGoStatusWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: InfrastructureProvider()) { entry in
      InfrastructureWidgetView(entry: entry)
    }
    .configurationDisplayName("DployGo Status")
    .description("See running, stopped, and failed services at a glance.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
