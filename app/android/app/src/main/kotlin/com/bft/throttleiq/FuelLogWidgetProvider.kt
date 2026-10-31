package com.bft.throttleiq

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 2x1 "Log fuel" launcher.
 *
 * Stateless, like [StartRideWidgetProvider]. Tapping launches MainActivity
 * with [FUEL_LOG_URI], which the app routes to the add-fill-up form for the
 * active bike (see `registerFuelLogHandler` in app.dart).
 */
class FuelLogWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val theme = WidgetTheme.from(context, widgetData)
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_fuel_log).apply {
                applyPanelTheme(theme)
                applyCtaTheme(theme)
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse(FUEL_LOG_URI)
                )
                setOnClickPendingIntent(R.id.widget_fuel_log_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
