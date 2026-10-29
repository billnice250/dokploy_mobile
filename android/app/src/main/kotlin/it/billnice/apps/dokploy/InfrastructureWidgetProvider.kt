package it.billnice.apps.dokploy

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class InfrastructureWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { updateWidget(context, manager, it) }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = android.content.ComponentName(
                context,
                InfrastructureWidgetProvider::class.java,
            )
            manager.getAppWidgetIds(component).forEach { updateWidget(context, manager, it) }
        }

        private fun updateWidget(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int,
        ) {
            val prefs = context.getSharedPreferences("dploygo_widget", Context.MODE_PRIVATE)
            val instance = prefs.getString("instanceName", "Open DployGo") ?: "Open DployGo"
            val running = prefs.getInt("running", 0)
            val stopped = prefs.getInt("stopped", 0)
            val failed = prefs.getInt("failed", 0)
            val updatedAt = prefs.getString("updatedAt", "") ?: ""

            val views = RemoteViews(context.packageName, R.layout.infrastructure_widget)
            views.setTextViewText(R.id.widget_instance, instance)
            views.setTextViewText(R.id.widget_running, running.toString())
            views.setTextViewText(R.id.widget_stopped, stopped.toString())
            views.setTextViewText(R.id.widget_failed, failed.toString())
            views.setTextViewText(
                R.id.widget_updated,
                if (updatedAt.isBlank()) "Refresh the app to load status" else "Updated ${updatedAt.take(16).replace('T', ' ')}",
            )
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pending = PendingIntent.getActivity(
                    context,
                    0,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_root, pending)
            }
            manager.updateAppWidget(widgetId, views)
        }
    }
}
