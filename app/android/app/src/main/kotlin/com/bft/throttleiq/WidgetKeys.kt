package com.bft.throttleiq

/**
 * The Dart <-> native contract for home-screen widget data.
 *
 * These strings must stay identical to the `kWidgetKey*` constants in
 * `lib/core/services/home_widget_service.dart` and to the keys read by the iOS
 * WidgetKit bundle in `ios/ThrottleIQWidget/ThrottleIQWidget.swift`. A typo
 * here does not fail the build — it silently renders the placeholder forever,
 * so change all three sides together.
 *
 * Every "display" value arrives pre-formatted from Dart ("128.4 km",
 * "Oil Change in 240.0 km"). Nothing in this package formats numbers; the
 * `_RAW` twins exist only for future native computation.
 */
object WidgetKeys {
    // Ride stats
    const val WEEKLY_KM = "ti_weekly_km"
    const val WEEKLY_KM_RAW = "ti_weekly_km_raw"
    const val TOTAL_KM = "ti_total_km"
    const val TOTAL_KM_RAW = "ti_total_km_raw"
    const val RIDE_COUNT = "ti_ride_count"
    const val RIDE_COUNT_RAW = "ti_ride_count_raw"

    // Maintenance
    const val BIKE_NAME = "ti_bike_name"
    const val SERVICE_LABEL = "ti_service_label"
    const val SERVICE_SUMMARY = "ti_service_summary"
    const val KM_UNTIL_DUE = "ti_km_until_due"
    const val KM_UNTIL_DUE_RAW = "ti_km_until_due_raw"
    const val OVERDUE = "ti_overdue"

    // Apex Hunter (Lean Angle)
    const val MAX_LEAN_LEFT = "ti_max_lean_left"
    const val MAX_LEAN_LEFT_RAW = "ti_max_lean_left_raw"
    const val MAX_LEAN_RIGHT = "ti_max_lean_right"
    const val MAX_LEAN_RIGHT_RAW = "ti_max_lean_right_raw"
    const val LEAN_RATING = "ti_lean_rating"
    const val LEAN_SYMMETRY = "ti_lean_symmetry"
    const val APEX_UPDATED_AT = "ti_apex_updated_at"
}

/**
 * Deep link carried by the Start Ride widget's launch intent.
 *
 * The intent is *explicit* (`Intent(context, MainActivity::class.java)` built
 * by HomeWidgetLaunchIntent), so no manifest intent-filter is needed for the
 * tap to work — the URI rides along as the intent data. Dart reads it back
 * with `HomeWidget.initiallyLaunchedFromHomeWidget()` / `HomeWidget.widgetClicked`
 * and routes to the Record screen — see `HomeWidgetService.registerStartRideHandler`.
 */
const val START_RIDE_URI = "throttleiq://startride"

/** Deep link carried by the Start Auto-Tracking widget's launch intent. */
const val AUTO_TRACKING_URI = "throttleiq://autotracking"

/** Deep link carried by the Apex Hunter widget's launch intent. */
const val APEX_HUNTER_URI = "throttleiq://apexhunter"
