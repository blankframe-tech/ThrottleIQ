package com.bft.throttleiq

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 4x2 Apex Hunter widget: displays maximum left and right lean angles,
 * lean rating, and symmetry score.
 *
 * Reads pre-formatted strings published by `HomeWidgetService.publishApexHunter`.
 */
class ApexHunterWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val placeholder = context.getString(R.string.widget_placeholder_value)
        val noData = context.getString(R.string.widget_placeholder_no_data)

        val leanLeft = widgetData.getStringOrNull(WidgetKeys.MAX_LEAN_LEFT) ?: placeholder
        val leanRight = widgetData.getStringOrNull(WidgetKeys.MAX_LEAN_RIGHT) ?: placeholder
        val rating = widgetData.getStringOrNull(WidgetKeys.LEAN_RATING) ?: noData
        val symmetry = widgetData.getStringOrNull(WidgetKeys.LEAN_SYMMETRY) ?: placeholder

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_apex_hunter).apply {
                setTextViewText(R.id.widget_apex_left_value, leanLeft)
                setTextViewText(R.id.widget_apex_right_value, leanRight)
                setTextViewText(R.id.widget_apex_rating, rating)
                setTextViewText(R.id.widget_apex_symmetry, symmetry)

                setOnClickPendingIntent(
                    R.id.widget_apex_hunter_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse(APEX_HUNTER_URI)
                    )
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
