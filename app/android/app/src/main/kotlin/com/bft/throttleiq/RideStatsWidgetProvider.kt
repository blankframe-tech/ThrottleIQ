package com.bft.throttleiq

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 4x2 ride stats panel: distance this week and all time, plus a ride count.
 *
 * Reads only pre-formatted strings published by
 * `HomeWidgetService.publishRideStats`. When a key is missing — widget added
 * before the app ever ran, or a fresh install — it falls back to the
 * placeholder strings so the panel never renders as an empty box.
 */
class RideStatsWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val placeholder = context.getString(R.string.widget_placeholder_value)
        val noData = context.getString(R.string.widget_placeholder_no_data)

        val weekly = widgetData.getStringOrNull(WidgetKeys.WEEKLY_KM) ?: placeholder
        val total = widgetData.getStringOrNull(WidgetKeys.TOTAL_KM) ?: placeholder
        val rides = widgetData.getStringOrNull(WidgetKeys.RIDE_COUNT) ?: noData

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_ride_stats).apply {
                setTextViewText(R.id.widget_stats_weekly_value, weekly)
                setTextViewText(R.id.widget_stats_total_value, total)
                setTextViewText(R.id.widget_stats_rides, rides)

                setOnClickPendingIntent(
                    R.id.widget_ride_stats_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("throttleiq://stats")
                    )
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

/**
 * `getString` with a null default, kept separate because a value written as
 * something other than a String (an older build, a partially-migrated key)
 * would otherwise throw ClassCastException inside onUpdate and leave the
 * widget stuck showing "Problem loading widget".
 */
internal fun SharedPreferences.getStringOrNull(key: String): String? = try {
    getString(key, null)?.takeIf { it.isNotBlank() }
} catch (e: ClassCastException) {
    null
}
