//
//  ThrottleIQWidget.swift
//  ThrottleIQWidget
//
//  Home-screen widgets for ThrottleIQ: Start Ride, Start Auto-Tracking, Ride
//  Stats, Maintenance.
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
//  The ThrottleIQWidget target is registered in Runner.xcodeproj and builds
//  as part of `flutter build ios` — see README.md in this folder for what
//  that got you automatically versus what still needs your Apple Developer
//  account (a signing team, and the App Group on the developer portal).
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

    // Apex Hunter (Lean Angle)
    static let maxLeanLeft = "ti_max_lean_left"
    static let maxLeanLeftRaw = "ti_max_lean_left_raw"
    static let maxLeanRight = "ti_max_lean_right"
    static let maxLeanRightRaw = "ti_max_lean_right_raw"
    static let leanRating = "ti_lean_rating"
    static let leanSymmetry = "ti_lean_symmetry"
    static let apexUpdatedAt = "ti_apex_updated_at"

    // Theme — `#AARRGGBB` strings from `widgetThemeData` in Dart.
    static let themeBackground = "ti_theme_background"
    static let themeSurface = "ti_theme_surface"
    static let themeBorder = "ti_theme_border"
    static let themeInk = "ti_theme_ink"
    static let themePrimary = "ti_theme_primary"
    static let themeOnPrimary = "ti_theme_on_primary"
    static let themeAccent = "ti_theme_accent"
    static let themeTextPrimary = "ti_theme_text_primary"
    static let themeTextMuted = "ti_theme_text_muted"
    static let themeTextTertiary = "ti_theme_text_tertiary"
    static let themeDanger = "ti_theme_danger"
    static let themeIsDark = "ti_theme_is_dark"
    static let themeMode = "ti_theme_mode"
}

enum Placeholder {
    static let value = "—"
    static let noData = "No data yet"
    static let noService = "No service data yet"
}

// MARK: - Theme tokens

/// The app's active color theme, published by `HomeWidgetService.publishTheme`
/// as `#AARRGGBB` strings under the `ti_theme_*` keys. Every token is read at
/// render time, so a theme change in the app shows on the next reload (the
/// app reloads every widget right after publishing). A missing or malformed
/// key falls back to the Carbon Mono value below — what the widgets looked
/// like before they followed the theme, and what a widget placed before the
/// app ever ran still shows.
enum WidgetPalette {
    static var background: Color { themed(WidgetKeys.themeBackground, 0xFF0D0D0D) }
    static var surface: Color { themed(WidgetKeys.themeSurface, 0xFF161616) }
    static var border: Color { themed(WidgetKeys.themeBorder, 0xFF393939) }
    static var primary: Color { themed(WidgetKeys.themePrimary, 0xFFC8FF3D) }
    static var onPrimary: Color { themed(WidgetKeys.themeOnPrimary, 0xFF0D0D0D) }
    static var accent: Color { themed(WidgetKeys.themeAccent, 0xFFD633FF) }
    static var textPrimary: Color { themed(WidgetKeys.themeTextPrimary, 0xFFF4F4F4) }
    static var textSecondary: Color { themed(WidgetKeys.themeTextMuted, 0xFF8A8A8A) }
    static var textTertiary: Color { themed(WidgetKeys.themeTextTertiary, 0xFF6F6F6F) }
    static var danger: Color { themed(WidgetKeys.themeDanger, 0xFFFA4D56) }

    /// Whether the published palette is a dark one. Defaults to true (Carbon
    /// Mono is dark) when nothing has been published.
    static var isDark: Bool {
        guard let defaults = ThrottleIQWidgetStore.defaults,
              defaults.object(forKey: WidgetKeys.themeIsDark) != nil else {
            return true
        }
        return defaults.bool(forKey: WidgetKeys.themeIsDark)
    }

    /// Sharp corners, 2–4dp — the app's shape system, deliberately not the
    /// system widget radius.
    static let cornerRadius: CGFloat = 3

    private static func themed(_ key: String, _ fallback: UInt32) -> Color {
        color(argb: ThrottleIQWidgetStore.string(key).flatMap(parseHex) ?? fallback)
    }

    /// `#AARRGGBB` or `#RRGGBB` (alpha defaults to opaque) → 0xAARRGGBB.
    static func parseHex(_ hex: String) -> UInt32? {
        var digits = hex.trimmingCharacters(in: .whitespaces)
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard let value = UInt32(digits, radix: 16) else { return nil }
        switch digits.count {
        case 8: return value
        case 6: return 0xFF000000 | value
        default: return nil
        }
    }

    private static func color(argb: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }
}

/// Small-caps monospaced section label, e.g. "RIDE STATS".
private struct SectionLabel: View {
    let text: String
    var color: Color = WidgetPalette.textSecondary

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .kerning(1.6)
            .foregroundColor(color)
            .lineLimit(1)
    }
}

/// The shared panel chrome: themed fill + hairline border, sharp corners.
private struct ThemedPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(WidgetPalette.background)
            .overlay(
                RoundedRectangle(cornerRadius: WidgetPalette.cornerRadius)
                    .stroke(WidgetPalette.border, lineWidth: 1)
            )
    }
}

/// `containerBackground` is required on iOS 17+ for widgets to render at all;
/// on 14–16 it does not exist, so this applies it conditionally rather than
/// raising the extension's deployment target.
private extension View {
    @ViewBuilder
    func themedContainerBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(WidgetPalette.background, for: .widget)
        } else {
            self.background(WidgetPalette.background)
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
        ThemedPanel {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "THROTTLEIQ")

                Text("START RIDE")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .kerning(0.8)
                    .foregroundColor(WidgetPalette.onPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(WidgetPalette.primary)
                    .cornerRadius(WidgetPalette.cornerRadius)
            }
            .padding(10)
        }
        .themedContainerBackground()
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

// MARK: - Start Auto-Tracking

struct AutoTrackingEntry: TimelineEntry {
    let date: Date
}

struct AutoTrackingProvider: TimelineProvider {
    func placeholder(in context: Context) -> AutoTrackingEntry {
        AutoTrackingEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (AutoTrackingEntry) -> Void) {
        completion(AutoTrackingEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AutoTrackingEntry>) -> Void) {
        // Stateless button, like Start Ride — one entry that never expires.
        completion(Timeline(entries: [AutoTrackingEntry(date: Date())], policy: .never))
    }
}

struct AutoTrackingWidgetView: View {
    var entry: AutoTrackingEntry

    var body: some View {
        ThemedPanel {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "THROTTLEIQ")

                Text("AUTO-TRACK")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .kerning(0.8)
                    .foregroundColor(WidgetPalette.onPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(WidgetPalette.primary)
                    .cornerRadius(WidgetPalette.cornerRadius)
            }
            .padding(10)
        }
        .themedContainerBackground()
        // Opens Settings rather than flipping the switch itself — enabling
        // auto-tracking can prompt for "Always" location and can fail, and
        // neither has anywhere to surface from a bare widget tap. See
        // HomeWidgetService.registerAutoTrackingHandler on the Dart side.
        .widgetURL(URL(string: "throttleiq://autotracking"))
    }
}

struct ThrottleIQAutoTrackingWidget: Widget {
    /// `kind` must equal `HomeWidgetService.iosAutoTrackingWidget` in Dart.
    let kind = "ThrottleIQAutoTrackingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AutoTrackingProvider()) { entry in
            AutoTrackingWidgetView(entry: entry)
        }
        .configurationDisplayName("Start Auto-Tracking")
        .description("One tap to open ThrottleIQ's automatic ride detection setting.")
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
            SectionLabel(text: label, color: WidgetPalette.textTertiary)
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
    @Environment(\.widgetFamily) var family
    var entry: RideStatsEntry

    var body: some View {
        if #available(iOS 16.0, *) {
            switch family {
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text("WEEK: \(entry.weeklyKm)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Text("TOTAL: \(entry.totalKm)")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                    Text(entry.rideCount)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            case .accessoryInline:
                Text("This week: \(entry.weeklyKm)")
            default:
                mediumView
            }
        } else {
            mediumView
        }
    }

    private var mediumView: some View {
        ThemedPanel {
            HStack(spacing: 0) {
                WidgetPalette.primary.frame(width: 3)

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "RIDE STATS")

                    HStack(alignment: .top, spacing: 10) {
                        StatColumn(
                            label: "THIS WEEK",
                            value: entry.weeklyKm,
                            valueColor: WidgetPalette.primary
                        )
                        StatColumn(
                            label: "ALL TIME",
                            value: entry.totalKm,
                            valueColor: WidgetPalette.textPrimary
                        )
                    }

                    Spacer(minLength: 0)

                    Text(entry.rideCount)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(WidgetPalette.textSecondary)
                        .lineLimit(1)
                }
                .padding(12)
            }
        }
        .themedContainerBackground()
    }
}

struct ThrottleIQRideStatsWidget: Widget {
    let kind = "ThrottleIQRideStatsWidget"

    private var supportedFamilies: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [.systemMedium, .accessoryRectangular, .accessoryInline]
        } else {
            return [.systemMedium]
        }
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RideStatsProvider()) { entry in
            RideStatsWidgetView(entry: entry)
        }
        .configurationDisplayName("Ride Stats")
        .description("Distance ridden this week and all time.")
        .supportedFamilies(supportedFamilies)
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
    @Environment(\.widgetFamily) var family
    var entry: MaintenanceEntry

    private var accentColor: Color {
        entry.hasData && entry.overdue ? WidgetPalette.danger : WidgetPalette.primary
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            switch family {
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("SERVICE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                        if entry.hasData {
                            Text(entry.overdue ? "OVERDUE" : "DUE")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                        }
                    }
                    Text(entry.summary)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                    Text(entry.bikeName)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            case .accessoryInline:
                Text("Next: \(entry.summary)")
            default:
                mediumView
            }
        } else {
            mediumView
        }
    }

    private var mediumView: some View {
        ThemedPanel {
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
                                    entry.overdue ? Color.white : WidgetPalette.onPrimary
                                )
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(accentColor)
                                .cornerRadius(2)
                        }
                    }

                    Text(entry.summary)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(WidgetPalette.textPrimary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    Text(entry.bikeName)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(WidgetPalette.textSecondary)
                        .lineLimit(1)
                }
                .padding(10)
            }
        }
        .themedContainerBackground()
    }
}

struct ThrottleIQMaintenanceWidget: Widget {
    let kind = "ThrottleIQMaintenanceWidget"

    private var supportedFamilies: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [.systemMedium, .accessoryRectangular, .accessoryInline]
        } else {
            return [.systemMedium]
        }
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MaintenanceProvider()) { entry in
            MaintenanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Maintenance")
        .description("The next service due on your bike.")
        .supportedFamilies(supportedFamilies)
    }
}

// MARK: - Apex Hunter

struct ApexHunterEntry: TimelineEntry {
    let date: Date
    let left: String
    let right: String
    let rating: String
    let symmetry: String
    let hasData: Bool

    static let placeholder = ApexHunterEntry(
        date: Date(),
        left: Placeholder.value,
        right: Placeholder.value,
        rating: Placeholder.noData,
        symmetry: Placeholder.value,
        hasData: false
    )

    static func current() -> ApexHunterEntry {
        let left = ThrottleIQWidgetStore.string(WidgetKeys.maxLeanLeft)
        let right = ThrottleIQWidgetStore.string(WidgetKeys.maxLeanRight)
        return ApexHunterEntry(
            date: Date(),
            left: left ?? Placeholder.value,
            right: right ?? Placeholder.value,
            rating: ThrottleIQWidgetStore.string(WidgetKeys.leanRating) ?? Placeholder.noData,
            symmetry: ThrottleIQWidgetStore.string(WidgetKeys.leanSymmetry) ?? Placeholder.value,
            hasData: left != nil || right != nil
        )
    }
}

struct ApexHunterProvider: TimelineProvider {
    func placeholder(in context: Context) -> ApexHunterEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ApexHunterEntry) -> Void) {
        completion(context.isPreview ? .placeholder : .current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ApexHunterEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [.current()], policy: .after(next)))
    }
}

struct ApexHunterWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: ApexHunterEntry

    var body: some View {
        if #available(iOS 16.0, *) {
            switch family {
            case .accessoryCircular:
                circularAccessoryView
            case .accessoryRectangular:
                rectangularAccessoryView
            case .accessoryInline:
                Text("Apex: L \(entry.left) / R \(entry.right) (\(entry.rating))")
            case .systemSmall:
                smallView
            default:
                mediumView
            }
        } else {
            switch family {
            case .systemSmall:
                smallView
            default:
                mediumView
            }
        }
    }

    @available(iOS 16.0, *)
    private var circularAccessoryView: some View {
        VStack(spacing: 1) {
            Text("L \(entry.left)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
            Text("R \(entry.right)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
            Text(entry.rating)
                .font(.system(size: 7, weight: .medium, design: .monospaced))
        }
    }

    @available(iOS 16.0, *)
    private var rectangularAccessoryView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("APEX HUNTER")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                Spacer()
                Text(entry.rating)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
            }
            HStack {
                Text("L \(entry.left)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                Text("•")
                Text("R \(entry.right)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            Text("SYM: \(entry.symmetry)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private var smallView: some View {
        ThemedPanel {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    SectionLabel(text: "APEX HUNTER")
                    Spacer()
                    if entry.hasData {
                        Text(entry.rating)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(WidgetPalette.onPrimary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(WidgetPalette.primary)
                            .cornerRadius(2)
                    }
                }

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("LEFT")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(WidgetPalette.textTertiary)
                        Text(entry.left)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(WidgetPalette.primary)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("RIGHT")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(WidgetPalette.textTertiary)
                        Text(entry.right)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(WidgetPalette.textPrimary)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)

                Text("SYM: \(entry.symmetry)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(WidgetPalette.textSecondary)
                    .lineLimit(1)
            }
            .padding(10)
        }
        .themedContainerBackground()
        .widgetURL(URL(string: "throttleiq://apexhunter"))
    }

    private var mediumView: some View {
        ThemedPanel {
            HStack(spacing: 0) {
                WidgetPalette.primary.frame(width: 3)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        SectionLabel(text: "APEX HUNTER · LEAN ANGLE")
                        Spacer()
                        if entry.hasData {
                            Text(entry.rating)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(WidgetPalette.onPrimary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(WidgetPalette.primary)
                                .cornerRadius(2)
                        }
                    }

                    HStack(alignment: .top, spacing: 16) {
                        StatColumn(
                            label: "MAX LEFT",
                            value: entry.left,
                            valueColor: WidgetPalette.primary
                        )
                        StatColumn(
                            label: "MAX RIGHT",
                            value: entry.right,
                            valueColor: WidgetPalette.textPrimary
                        )
                        StatColumn(
                            label: "SYMMETRY",
                            value: entry.symmetry,
                            valueColor: WidgetPalette.textSecondary
                        )
                    }

                    Spacer(minLength: 0)

                    Text("Calculated from gyroscope and lateral gravity telemetry")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(WidgetPalette.textTertiary)
                        .lineLimit(1)
                }
                .padding(12)
            }
        }
        .themedContainerBackground()
        .widgetURL(URL(string: "throttleiq://apexhunter"))
    }
}

struct ThrottleIQApexHunterWidget: Widget {
    let kind = "ThrottleIQApexHunterWidget"

    private var supportedFamilies: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [
                .systemSmall,
                .systemMedium,
                .accessoryRectangular,
                .accessoryCircular,
                .accessoryInline
            ]
        } else {
            return [.systemSmall, .systemMedium]
        }
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ApexHunterProvider()) { entry in
            ApexHunterWidgetView(entry: entry)
        }
        .configurationDisplayName("Apex Hunter")
        .description("Maximum lean angles, symmetry, and cornering grade.")
        .supportedFamilies(supportedFamilies)
    }
}

// MARK: - Bundle

@main
struct ThrottleIQWidgetBundle: WidgetBundle {
    var body: some Widget {
        ThrottleIQStartRideWidget()
        ThrottleIQAutoTrackingWidget()
        ThrottleIQRideStatsWidget()
        ThrottleIQMaintenanceWidget()
        ThrottleIQApexHunterWidget()
    }
}
