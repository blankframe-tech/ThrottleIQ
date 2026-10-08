package com.bft.throttleiq

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 4x1 "next service due" panel.
 *
 * The summary line arrives fully composed from Dart
 * (`formatNextServiceSummary`), so this only decides colour: the left accent
 * bar and the status chip flip from the theme's primary to danger red when
 * overdue, which is the part a rider reads without reading.
 */
class MaintenanceWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val placeholder = context.getString(R.string.widget_placeholder_value)
        val noService = context.getString(R.string.widget_placeholder_no_service)

        val summary = widgetData.getStringOrNull(WidgetKeys.SERVICE_SUMMARY) ?: noService
        val bike = widgetData.getStringOrNull(WidgetKeys.BIKE_NAME) ?: placeholder
        val overdue = widgetData.getBooleanOrFalse(WidgetKeys.OVERDUE)

        // Nothing published yet: no reason to shout DUE at a rider whose bike
        // we know nothing about, so the chip is hidden by rendering it blank.
        val hasData = widgetData.getStringOrNull(WidgetKeys.SERVICE_SUMMARY) != null

        val flagText = when {
            !hasData -> ""
            overdue -> context.getString(R.string.widget_maintenance_overdue_flag)
            else -> context.getString(R.string.widget_maintenance_due_flag)
        }

        val theme = WidgetTheme.from(context, widgetData)
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_maintenance).apply {
                setTextViewText(R.id.widget_maintenance_summary, summary)
                setTextViewText(R.id.widget_maintenance_bike, bike)
                setTextViewText(R.id.widget_maintenance_flag, flagText)

                applyPanelTheme(theme)
                setTextColor(R.id.widget_maintenance_summary, theme.textPrimary)
                setTextColor(R.id.widget_maintenance_bike, theme.textMuted)

                // Plain color fills (not the drawable swap this used to do) so
                // the accent and chip follow the app theme; danger stays red.
                val accent = if (overdue && hasData) theme.danger else theme.primary
                setInt(R.id.widget_maintenance_accent, "setBackgroundColor", accent)
                when {
                    overdue && hasData -> {
                        setInt(R.id.widget_maintenance_flag, "setBackgroundColor", theme.danger)
                        setTextColor(R.id.widget_maintenance_flag, Color.WHITE)
                    }
                    hasData -> {
                        setInt(R.id.widget_maintenance_flag, "setBackgroundColor", theme.primary)
                        setTextColor(R.id.widget_maintenance_flag, theme.onPrimary)
                    }
                    else -> setInt(
                        R.id.widget_maintenance_flag,
                        "setBackgroundColor",
                        Color.TRANSPARENT
                    )
                }

                setOnClickPendingIntent(
                    R.id.widget_maintenance_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("throttleiq://maintenance")
                    )
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

/** See [getStringOrNull] — same defensive reasoning for a mistyped boolean. */
internal fun SharedPreferences.getBooleanOrFalse(key: String): Boolean = try {
    getBoolean(key, false)
} catch (e: ClassCastException) {
    false
}
