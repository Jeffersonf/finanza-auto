package com.jeffersonf.finanza_auto

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Locale

class FinanzaSummaryWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it) }
    }

    override fun onEnabled(context: Context) {
        updateAll(context)
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, FinanzaSummaryWidget::class.java)
            manager.getAppWidgetIds(component).forEach { update(context, manager, it) }
        }

        private fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val data = readData(context)
            val car = data.optJSONObject("car") ?: data.optJSONObject("vehicle") ?: data
            val events = car.optJSONArray("events") ?: car.optJSONArray("items")
            var total = 0.0
            var count = 0
            if (events != null) {
                for (index in 0 until events.length()) {
                    total += events.optJSONObject(index)?.optDouble("amount", 0.0) ?: 0.0
                    count++
                }
            }
            val views = RemoteViews(context.packageName, R.layout.widget_finanza_summary)
            views.setTextViewText(R.id.widget_total, money(total))
            views.setTextViewText(R.id.widget_count, "$count registros no carro")
            val intent = Intent(context, MainActivity::class.java)
            val pending = PendingIntent.getActivity(context, 4101, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_open, pending)
            manager.updateAppWidget(id, views)
        }

        private fun readData(context: Context): JSONObject {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val saved = prefs.getString("flutter.finanza_auto_flutter_state", null)
            if (!saved.isNullOrBlank()) {
                runCatching { return JSONObject(saved) }
            }
            return runCatching {
                context.assets.open("finanza-auto-backup.json").bufferedReader().use { JSONObject(it.readText()) }
            }.getOrElse { JSONObject() }
        }

        private fun money(value: Double): String = NumberFormat.getCurrencyInstance(Locale("pt", "BR")).format(value)
    }
}
