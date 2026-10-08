package com.bft.throttleiq

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews

/**
 * The app's active color theme, as published by
 * `HomeWidgetService.publishTheme` (the `ti_theme_*` keys in [WidgetKeys]).
 *
 * Read fresh on every `onUpdate`, so a theme change in the app shows on the
 * home screen the next time the widgets render (the app forces that render
 * right after publishing). Any key that is missing or unparseable — widget
 * placed before the app ever ran, an older build — falls back to the built-in
 * Carbon Mono color from `res/values/colors.xml`, which is exactly what the
 * widgets looked like before they followed the theme.
 */
internal class WidgetTheme(
    val background: Int,
    val border: Int,
    val primary: Int,
    val onPrimary: Int,
    val textPrimary: Int,
    val textMuted: Int,
    val textTertiary: Int,
    val danger: Int,
) {
    companion object {
        fun from(context: Context, prefs: SharedPreferences): WidgetTheme {
            fun color(key: String, fallback: Int): Int =
                prefs.getStringOrNull(key)?.let { hex ->
                    try {
                        Color.parseColor(hex)
                    } catch (e: IllegalArgumentException) {
                        null
                    }
                } ?: context.getColor(fallback)

            return WidgetTheme(
                background = color(WidgetKeys.THEME_BACKGROUND, R.color.widget_background),
                border = color(WidgetKeys.THEME_BORDER, R.color.widget_border),
                primary = color(WidgetKeys.THEME_PRIMARY, R.color.widget_primary),
                onPrimary = color(WidgetKeys.THEME_ON_PRIMARY, R.color.widget_on_primary),
                textPrimary = color(WidgetKeys.THEME_TEXT_PRIMARY, R.color.widget_text_primary),
                textMuted = color(WidgetKeys.THEME_TEXT_MUTED, R.color.widget_text_secondary),
                textTertiary = color(WidgetKeys.THEME_TEXT_TERTIARY, R.color.widget_text_tertiary),
                danger = color(WidgetKeys.THEME_DANGER, R.color.widget_danger),
            )
        }
    }
}

/**
 * Recolors the panel chrome every widget layout shares: the two tintable
 * images behind the content (`widget_bg_border`, `widget_bg_fill`) and the
 * section title. Each provider then colors its own figures.
 */
internal fun RemoteViews.applyPanelTheme(theme: WidgetTheme) {
    setInt(R.id.widget_bg_border, "setColorFilter", theme.border)
    setInt(R.id.widget_bg_fill, "setColorFilter", theme.background)
    setTextColor(R.id.widget_title, theme.textMuted)
}

/** The solid call-to-action block on the two launcher widgets. */
internal fun RemoteViews.applyCtaTheme(theme: WidgetTheme) {
    setInt(R.id.widget_cta_block, "setBackgroundColor", theme.primary)
    setTextColor(R.id.widget_cta_text, theme.onPrimary)
}
