package com.bft.throttleiq

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 2x1 "Start Auto-Tracking" launcher.
 *
 * Stateless, like [StartRideWidgetProvider] — no published data, correct from
 * the moment it is dropped on the home screen. Tapping launches MainActivity
 * with [AUTO_TRACKING_URI], which the app routes to Settings rather than
 * flipping the switch itself: turning on all-day background location from a
 * single home-screen tap, with no chance to explain the battery/permission
 * trade-off or surface a failure, is exactly the kind of surprise a tap
 * should not spring. See `AutoTrackingTile` for that trade-off explanation.
 */
class AutoTrackingWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_auto_tracking).apply {
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse(AUTO_TRACKING_URI)
                )
                setOnClickPendingIntent(R.id.widget_auto_tracking_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
