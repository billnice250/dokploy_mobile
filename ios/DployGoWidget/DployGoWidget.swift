import SwiftUI
import WidgetKit
import UIKit

private let widgetGroup = "group.it.billnice.apps.dokploy"

private struct DployGoWidgetSurface: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 17.0, *) {
      content.containerBackground(surface, for: .widget)
    } else {
      content.background(surface)
    }
  }

  private var surface: Color {
    Color(uiColor: UIColor { traits in
      if traits.userInterfaceStyle == .dark {
        UIColor(red: 10 / 255, green: 10 / 255, blue: 10 / 255, alpha: 1)
      } else {
        UIColor(red: 244 / 255, green: 244 / 255, blue: 245 / 255, alpha: 1)
      }
    })
  }
}

struct InfrastructureEntry: TimelineEntry {
  let date: Date
  let instanceName: String
  let running: Int
  let stopped: Int
  let failed: Int
  let serverName: String
  let cpuPercent: Double?
  let diskPercent: Double?
  let diskUsedGb: Double?
  let diskTotalGb: Double?

  static let placeholder = InfrastructureEntry(
    date: .now,
    instanceName: "Demo Infrastructure",
    running: 12,
    stopped: 2,
    failed: 1,
    serverName: "Home Server",
    cpuPercent: 24,
    diskPercent: 61,
    diskUsedGb: 122,
    diskTotalGb: 200
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
      failed: defaults?.integer(forKey: "failed") ?? 0,
      serverName: defaults?.string(forKey: "serverName") ?? "",
      cpuPercent: defaults?.object(forKey: "cpuPercent") as? Double,
      diskPercent: defaults?.object(forKey: "diskPercent") as? Double,
      diskUsedGb: defaults?.object(forKey: "diskUsedGb") as? Double,
      diskTotalGb: defaults?.object(forKey: "diskTotalGb") as? Double
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
          .foregroundStyle(.primary)
        Text("DPLOYGO")
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .tracking(1.2)
          .foregroundStyle(.secondary)
        Spacer(minLength: 2)
        Image(systemName: entry.failed > 0 ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
          .foregroundStyle(entry.failed > 0 ? Color.orange : Color.green)
      }
      Text(entry.instanceName)
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .lineLimit(1)
        .foregroundStyle(.primary)
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
          .foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .modifier(DployGoWidgetSurface())
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
        .foregroundStyle(.secondary)
    }
  }
}

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

struct ServerMetricsWidgetView: View {
  let entry: InfrastructureEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 6) {
        Image(systemName: "server.rack")
          .foregroundStyle(Color.accentColor)
        Text("SERVER METRICS")
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .tracking(0.8)
          .foregroundStyle(.secondary)
        Spacer()
      }
      Text(entry.serverName.isEmpty ? "No monitored server" : entry.serverName)
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .lineLimit(1)
        .foregroundStyle(.primary)
      HStack(spacing: 12) {
        metric("CPU", value: entry.cpuPercent)
        metric("DISK", value: entry.diskPercent)
      }
      if let used = entry.diskUsedGb, let total = entry.diskTotalGb {
        Text("\(used, specifier: "%.1f") / \(total, specifier: "%.1f") GB used")
          .font(.system(size: 10, weight: .medium, design: .rounded))
          .foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .modifier(DployGoWidgetSurface())
    .widgetURL(URL(string: "dokploy-mobile://app"))
  }

  private func metric(_ label: String, value: Double?) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value.map { "\(Int($0.rounded()))%" } ?? "—")
        .font(.system(size: 22, weight: .bold, design: .rounded))
        .foregroundStyle(.primary)
      Text(label)
        .font(.system(size: 8, weight: .bold, design: .rounded))
        .tracking(0.5)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct DployGoServerMetricsWidget: Widget {
  let kind = "DployGoServerMetricsWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: InfrastructureProvider()) { entry in
      ServerMetricsWidgetView(entry: entry)
    }
    .configurationDisplayName("DployGo Server Metrics")
    .description("See CPU and disk usage for your monitored server.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct CombinedWidgetView: View {
  let entry: InfrastructureEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        Image(systemName: "water.waves")
          .foregroundStyle(.primary)
        Text("DPLOYGO")
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .tracking(1.0)
          .foregroundStyle(.secondary)
        Spacer()
        Image(systemName: entry.failed > 0 ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
          .foregroundStyle(entry.failed > 0 ? Color.orange : Color.green)
      }
      Text(entry.instanceName)
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .lineLimit(1)
        .foregroundStyle(.primary)
      HStack(alignment: .firstTextBaseline, spacing: 0) {
        serviceMetric(entry.running, label: "RUNNING", color: .green)
        Spacer(minLength: 4)
        serviceMetric(entry.stopped, label: "STOPPED", color: .orange)
        Spacer(minLength: 4)
        serviceMetric(entry.failed, label: "FAILED", color: .red)
      }
      Divider()
      HStack(spacing: 10) {
        resourceMetric("CPU", value: entry.cpuPercent)
        resourceMetric("DISK", value: entry.diskPercent)
        Spacer(minLength: 0)
      }
      if let used = entry.diskUsedGb, let total = entry.diskTotalGb {
        Text("\(entry.serverName.isEmpty ? "Server" : entry.serverName) · \(used, specifier: "%.1f") / \(total, specifier: "%.1f") GB")
          .font(.system(size: 9, weight: .medium, design: .rounded))
          .lineLimit(1)
          .foregroundStyle(.secondary)
      } else if !entry.serverName.isEmpty {
        Text(entry.serverName)
          .font(.system(size: 9, weight: .medium, design: .rounded))
          .lineLimit(1)
          .foregroundStyle(.secondary)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .modifier(DployGoWidgetSurface())
    .widgetURL(URL(string: "dokploy-mobile://app"))
  }

  private func serviceMetric(_ value: Int, label: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text("\(value)")
        .font(.system(size: 19, weight: .bold, design: .rounded))
        .foregroundStyle(color)
      Text(label)
        .font(.system(size: 7, weight: .bold, design: .rounded))
        .tracking(0.3)
        .foregroundStyle(.secondary)
    }
  }

  private func resourceMetric(_ label: String, value: Double?) -> some View {
    HStack(spacing: 4) {
      Text(label)
        .font(.system(size: 8, weight: .bold, design: .rounded))
        .foregroundStyle(.secondary)
      Text(value.map { "\(Int($0.rounded()))%" } ?? "—")
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .foregroundStyle(.primary)
    }
  }
}

struct DployGoCombinedWidget: Widget {
  let kind = "DployGoCombinedWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: InfrastructureProvider()) { entry in
      CombinedWidgetView(entry: entry)
    }
    .configurationDisplayName("DployGo All-in-One")
    .description("See service health, CPU, and disk usage together.")
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}

@main
struct DployGoWidgets: WidgetBundle {
  var body: some Widget {
    DployGoStatusWidget()
    DployGoServerMetricsWidget()
    DployGoCombinedWidget()
  }
}
