package com.bft.throttleiq

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.view.View
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

                // The accent bar is square, so a plain color fill is fine. The
                // chip is tinted through its rounded background image so it
                // keeps its 2dp corners; danger stays red when overdue.
                val accent = if (overdue && hasData) theme.danger else theme.primary
                setInt(R.id.widget_maintenance_accent, "setBackgroundColor", accent)
                when {
                    overdue && hasData -> {
                        setViewVisibility(R.id.widget_maintenance_flag_bg, View.VISIBLE)
                        setInt(R.id.widget_maintenance_flag_bg, "setColorFilter", theme.danger)
                        setTextColor(R.id.widget_maintenance_flag, Color.WHITE)
                    }
                    hasData -> {
                        setViewVisibility(R.id.widget_maintenance_flag_bg, View.VISIBLE)
                        setInt(R.id.widget_maintenance_flag_bg, "setColorFilter", theme.primary)
                        setTextColor(R.id.widget_maintenance_flag, theme.onPrimary)
                    }
                    // No data: blank label and no chip fill. (A transparent
                    // color filter would leave the lime drawable showing, so
                    // the image is hidden instead.)
                    else -> setViewVisibility(R.id.widget_maintenance_flag_bg, View.GONE)
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
