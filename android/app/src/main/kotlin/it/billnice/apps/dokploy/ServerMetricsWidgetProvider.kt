package it.billnice.apps.dokploy

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.util.Locale
import kotlin.math.roundToInt

class ServerMetricsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { id ->
            appWidgetManager.updateAppWidget(id, createViews(context))
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, ServerMetricsWidgetProvider::class.java)
            manager.getAppWidgetIds(component).forEach { id ->
                manager.updateAppWidget(id, createViews(context))
            }
        }

        private fun createViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.server_metrics_widget)
            val prefs = context.getSharedPreferences("dploygo_widget", Context.MODE_PRIVATE)
            val serverName = prefs.getString("serverName", "")?.takeIf { it.isNotBlank() }
                ?: "No monitored server"
            views.setTextViewText(R.id.server_name, serverName)
            views.setTextViewText(R.id.cpu_value, percent(prefs.getString("cpuPercent", "")))
            views.setTextViewText(R.id.disk_value, percent(prefs.getString("diskPercent", "")))

            val used = prefs.getString("diskUsedGb", "")?.toDoubleOrNull()
            val total = prefs.getString("diskTotalGb", "")?.toDoubleOrNull()
            val detail = if (used != null && total != null) {
                String.format(Locale.getDefault(), "%.1f / %.1f GB used", used, total)
            } else {
                "Disk capacity unavailable"
            }
            views.setTextViewText(R.id.disk_detail, detail)

            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = android.net.Uri.parse("dokploy-mobile://app")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                2,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.server_metrics_root, pendingIntent)
            return views
        }

        private fun percent(raw: String?): String = raw?.toDoubleOrNull()
            ?.let { "${it.roundToInt()}%" } ?: "—"
    }
}
