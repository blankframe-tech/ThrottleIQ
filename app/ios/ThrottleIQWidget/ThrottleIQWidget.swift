//
//  ThrottleIQWidget.swift
//  ThrottleIQWidget
//
//  Home-screen widgets for ThrottleIQ: Start Ride, Ride Stats, Maintenance.
//
//  Data contract
//  -------------
//  Nothing here computes or formats anything. The Flutter side
//  (lib/core/services/home_widget_service.dart) writes fully-rendered strings
//  ("128.4 km", "Oil Change overdue by 240.0 km") into the shared App Group
//  UserDefaults, and this file reads them by key. The key strings below MUST
//  stay identical to the `kWidgetKey*` constants in that Dart file and to
//  WidgetKeys.kt on Android — a mismatch does not fail the build, it silently
//  renders the placeholder forever.
//
//  Setup
//  -----
//  This target is NOT registered in Runner.xcodeproj. Follow README.md in this
//  folder to create it in Xcode before any of this compiles.
//

import SwiftUI
import WidgetKit

// MARK: - Shared storage

enum ThrottleIQWidgetStore {
    /// Must match `HomeWidgetService.appGroupId` in Dart and the App Group
    /// capability on BOTH the Runner and ThrottleIQWidget targets.
    static let appGroupId = "group.com.bft.throttleiq"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    /// `home_widget` prefixes nothing on iOS — keys are stored verbatim — but
    /// this indirection keeps every read in one place and returns nil for
    /// empty strings so the caller's `??` placeholder wins.
    static func string(_ key: String) -> String? {
        guard let value = defaults?.string(forKey: key), !value.isEmpty else {
            return nil
        }
        return value
    }

    static func bool(_ key: String) -> Bool {
        defaults?.bool(forKey: key) ?? false
    }
}

enum WidgetKeys {
    // Ride stats
    static let weeklyKm = "ti_weekly_km"
    static let weeklyKmRaw = "ti_weekly_km_raw"
    static let totalKm = "ti_total_km"
    static let totalKmRaw = "ti_total_km_raw"
    static let rideCount = "ti_ride_count"
    static let rideCountRaw = "ti_ride_count_raw"

    // Maintenance
    static let bikeName = "ti_bike_name"
    static let serviceLabel = "ti_service_label"
    static let serviceSummary = "ti_service_summary"
    static let kmUntilDue = "ti_km_until_due"
    static let kmUntilDueRaw = "ti_km_until_due_raw"
    static let overdue = "ti_overdue"
}

enum Placeholder {
    static let value = "—"
    static let noData = "No data yet"
    static let noService = "No service data yet"
}

// MARK: - Carbon Mono design tokens

/// Mirrors AppColorPalette.carbonMono in lib/core/theme/app_theme_style.dart.
/// Widgets always render Carbon Mono regardless of the in-app theme toggle —
/// a widget sits on the wallpaper, and this is the brand mark there.
enum Carbon {
    static let background = Color(red: 0.051, green: 0.051, blue: 0.051) // #0D0D0D
    static let surface = Color(red: 0.086, green: 0.086, blue: 0.086)    // #161616
    static let border = Color(red: 0.224, green: 0.224, blue: 0.224)     // #393939
    static let primary = Color(red: 0.784, green: 1.0, blue: 0.239)      // #C8FF3D
    static let onPrimary = Color(red: 0.051, green: 0.051, blue: 0.051)  // #0D0D0D
    static let textPrimary = Color(red: 0.957, green: 0.957, blue: 0.957) // #F4F4F4
    static let textSecondary = Color(red: 0.541, green: 0.541, blue: 0.541) // #8A8A8A
    static let textTertiary = Color(red: 0.435, green: 0.435, blue: 0.435)  // #6F6F6F
    static let danger = Color(red: 0.980, green: 0.302, blue: 0.337)     // #FA4D56

    /// Sharp corners, 2–4dp — the app's shape system, deliberately not the
    /// system widget radius.
    static let cornerRadius: CGFloat = 3
}

/// Small-caps monospaced section label, e.g. "RIDE STATS".
private struct SectionLabel: View {
    let text: String
    var color: Color = Carbon.textSecondary

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .kerning(1.6)
            .foregroundColor(color)
            .lineLimit(1)
    }
}

/// The shared panel chrome: carbon fill + hairline border, sharp corners.
private struct CarbonPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Carbon.background)
            .overlay(
                RoundedRectangle(cornerRadius: Carbon.cornerRadius)
                    .stroke(Carbon.border, lineWidth: 1)
            )
    }
}

/// `containerBackground` is required on iOS 17+ for widgets to render at all;
/// on 14–16 it does not exist, so this applies it conditionally rather than
/// raising the extension's deployment target.
private extension View {
    @ViewBuilder
    func carbonContainerBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(Carbon.background, for: .widget)
        } else {
            self.background(Carbon.background)
        }
    }
}

// MARK: - Start Ride

struct StartRideEntry: TimelineEntry {
    let date: Date
}

struct StartRideProvider: TimelineProvider {
    func placeholder(in context: Context) -> StartRideEntry {
        StartRideEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (StartRideEntry) -> Void) {
        completion(StartRideEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StartRideEntry>) -> Void) {
        // Stateless button — nothing to refresh, so one entry that never expires.
        completion(Timeline(entries: [StartRideEntry(date: Date())], policy: .never))
    }
}

struct StartRideWidgetView: View {
    var entry: StartRideEntry

    var body: some View {
        CarbonPanel {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "THROTTLEIQ")

                Text("START RIDE")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .kerning(0.8)
                    .foregroundColor(Carbon.onPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Carbon.primary)
                    .cornerRadius(Carbon.cornerRadius)
            }
            .padding(10)
        }
        .carbonContainerBackground()
        .widgetURL(URL(string: "throttleiq://startride"))
    }
}

struct ThrottleIQStartRideWidget: Widget {
    /// `kind` must equal `HomeWidgetService.iosStartRideWidget` in Dart —
    /// that string is what `HomeWidget.updateWidget(iOSName:)` reloads.
    let kind = "ThrottleIQStartRideWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StartRideProvider()) { entry in
            StartRideWidgetView(entry: entry)
        }
        .configurationDisplayName("Start Ride")
        .description("One tap to open ThrottleIQ and start recording a ride.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Ride Stats

struct RideStatsEntry: TimelineEntry {
    let date: Date
    let weeklyKm: String
    let totalKm: String
    let rideCount: String

    /// What a brand-new widget shows before Flutter has ever published.
    static let placeholder = RideStatsEntry(
        date: Date(),
        weeklyKm: Placeholder.value,
        totalKm: Placeholder.value,
        rideCount: Placeholder.noData
    )

    static func current() -> RideStatsEntry {
        RideStatsEntry(
            date: Date(),
            weeklyKm: ThrottleIQWidgetStore.string(WidgetKeys.weeklyKm) ?? Placeholder.value,
            totalKm: ThrottleIQWidgetStore.string(WidgetKeys.totalKm) ?? Placeholder.value,
            rideCount: ThrottleIQWidgetStore.string(WidgetKeys.rideCount) ?? Placeholder.noData
        )
    }
}

struct RideStatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> RideStatsEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (RideStatsEntry) -> Void) {
        completion(context.isPreview ? .placeholder : .current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RideStatsEntry>) -> Void) {
        // The app pushes explicit reloads on every publish; this 30-minute
        // fallback only covers the case where the app has not run in a while.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [.current()], policy: .after(next)))
    }
}

private struct StatColumn: View {
    let label: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionLabel(text: label, color: Carbon.textTertiary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(valueColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RideStatsWidgetView: View {
    var entry: RideStatsEntry

    var body: some View {
        CarbonPanel {
            HStack(spacing: 0) {
                Carbon.primary.frame(width: 3)

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "RIDE STATS")

                    HStack(alignment: .top, spacing: 10) {
                        StatColumn(
                            label: "THIS WEEK",
                            value: entry.weeklyKm,
                            valueColor: Carbon.primary
                        )
                        StatColumn(
                            label: "ALL TIME",
                            value: entry.totalKm,
                            valueColor: Carbon.textPrimary
                        )
                    }

                    Spacer(minLength: 0)

                    Text(entry.rideCount)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(Carbon.textSecondary)
                        .lineLimit(1)
                }
                .padding(12)
            }
        }
        .carbonContainerBackground()
    }
}

struct ThrottleIQRideStatsWidget: Widget {
    let kind = "ThrottleIQRideStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RideStatsProvider()) { entry in
            RideStatsWidgetView(entry: entry)
        }
        .configurationDisplayName("Ride Stats")
        .description("Distance ridden this week and all time.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Maintenance

struct MaintenanceEntry: TimelineEntry {
    let date: Date
    let bikeName: String
    let summary: String
    let overdue: Bool

    /// True once Flutter has published at least once. Drives whether the
    /// DUE/OVERDUE chip is shown at all — shouting "DUE" about a bike we know
    /// nothing about would be a lie.
    let hasData: Bool

    static let placeholder = MaintenanceEntry(
        date: Date(),
        bikeName: Placeholder.value,
        summary: Placeholder.noService,
        overdue: false,
        hasData: false
    )

    static func current() -> MaintenanceEntry {
        let summary = ThrottleIQWidgetStore.string(WidgetKeys.serviceSummary)
        return MaintenanceEntry(
            date: Date(),
            bikeName: ThrottleIQWidgetStore.string(WidgetKeys.bikeName) ?? Placeholder.value,
            summary: summary ?? Placeholder.noService,
            overdue: ThrottleIQWidgetStore.bool(WidgetKeys.overdue),
            hasData: summary != nil
        )
    }
}

struct MaintenanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> MaintenanceEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (MaintenanceEntry) -> Void) {
        completion(context.isPreview ? .placeholder : .current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MaintenanceEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [.current()], policy: .after(next)))
    }
}

struct MaintenanceWidgetView: View {
    var entry: MaintenanceEntry

    private var accentColor: Color {
        entry.hasData && entry.overdue ? Carbon.danger : Carbon.primary
    }

    var body: some View {
        CarbonPanel {
            HStack(spacing: 0) {
                accentColor.frame(width: 3)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .center) {
                        SectionLabel(text: "NEXT SERVICE")
                        Spacer(minLength: 4)
                        if entry.hasData {
                            Text(entry.overdue ? "OVERDUE" : "DUE")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .kerning(0.8)
                                .foregroundColor(
                                    entry.overdue ? Carbon.textPrimary : Carbon.onPrimary
                                )
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(accentColor)
                                .cornerRadius(2)
                        }
                    }

                    Text(entry.summary)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Carbon.textPrimary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    Text(entry.bikeName)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(Carbon.textSecondary)
                        .lineLimit(1)
                }
                .padding(10)
            }
        }
        .carbonContainerBackground()
    }
}

struct ThrottleIQMaintenanceWidget: Widget {
    let kind = "ThrottleIQMaintenanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MaintenanceProvider()) { entry in
            MaintenanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Maintenance")
        .description("The next service due on your bike.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Bundle

@main
struct ThrottleIQWidgetBundle: WidgetBundle {
    var body: some Widget {
        ThrottleIQStartRideWidget()
        ThrottleIQRideStatsWidget()
        ThrottleIQMaintenanceWidget()
    }
}
