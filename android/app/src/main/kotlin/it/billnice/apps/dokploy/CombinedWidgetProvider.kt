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

class CombinedWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { appWidgetManager.updateAppWidget(it, createViews(context)) }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, CombinedWidgetProvider::class.java)
            manager.getAppWidgetIds(component).forEach { id ->
                manager.updateAppWidget(id, createViews(context))
            }
        }

        private fun createViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.combined_widget)
            val prefs = context.getSharedPreferences("dploygo_widget", Context.MODE_PRIVATE)
            views.setTextViewText(R.id.combined_instance, prefs.getString("instanceName", "Open DployGo"))
            views.setTextViewText(R.id.combined_running, "${prefs.getInt("running", 0)} running")
            views.setTextViewText(R.id.combined_stopped, "${prefs.getInt("stopped", 0)} stopped")
            views.setTextViewText(R.id.combined_failed, "${prefs.getInt("failed", 0)} failed")

            val serverName = prefs.getString("serverName", "")?.takeIf { it.isNotBlank() }
                ?: "No monitored server"
            views.setTextViewText(R.id.combined_server, serverName)
            views.setTextViewText(R.id.combined_cpu, "CPU  ${percent(prefs.getString("cpuPercent", ""))}")
            views.setTextViewText(R.id.combined_disk, "DISK  ${percent(prefs.getString("diskPercent", ""))}")

            val used = prefs.getString("diskUsedGb", "")?.toDoubleOrNull()
            val total = prefs.getString("diskTotalGb", "")?.toDoubleOrNull()
            val detail = if (used != null && total != null) {
                String.format(Locale.getDefault(), "%.1f / %.1f GB used", used, total)
            } else {
                "Disk capacity unavailable"
            }
            views.setTextViewText(R.id.combined_disk_detail, detail)

            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = android.net.Uri.parse("dokploy-mobile://app")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pending = PendingIntent.getActivity(
                context,
                3,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.combined_widget_root, pending)
            return views
        }

        private fun percent(raw: String?): String = raw?.toDoubleOrNull()
            ?.let { "${it.roundToInt()}%" } ?: "—"
    }
}
