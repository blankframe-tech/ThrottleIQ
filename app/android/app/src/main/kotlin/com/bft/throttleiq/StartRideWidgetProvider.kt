package com.bft.throttleiq

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 2x1 "Start Ride" launcher.
 *
 * Stateless — it renders no published data, so it is correct from the moment
 * it is dropped on the home screen even if the app has never been opened.
 * Tapping launches MainActivity with [START_RIDE_URI]; see
 * `AndroidManifest.xml` for the matching intent filter.
 */
class StartRideWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_start_ride).apply {
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse(START_RIDE_URI)
                )
                // Whole panel is the tap target, not just the lime block —
                // gloved hands, small widget.
                setOnClickPendingIntent(R.id.widget_start_ride_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
