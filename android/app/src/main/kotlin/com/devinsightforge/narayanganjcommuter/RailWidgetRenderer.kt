package com.devinsightforge.narayanganjcommuter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import org.json.JSONObject

object RailWidgetRenderer {
    private const val PAYLOAD_STORAGE_KEY = "nrs_widget_payload_v1"
    private const val DEEP_LINK_SCHEME = "com.devinsightforge.narayanganjcommuter"
    private const val EXPECTED_SCHEMA_VERSION = 1
    private const val FRESH_COMMUNITY_WINDOW_MS = 180_000L
    private const val MAX_USABLE_COMMUNITY_WINDOW_MS = 1_200_000L
    private const val STALE_PAYLOAD_THRESHOLD_MS = 1_800_000L

    fun updateCompactWidgets(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val payload = parsePayload(widgetData.getString(PAYLOAD_STORAGE_KEY, null))
        val nowMs = System.currentTimeMillis()
        for (widgetId in appWidgetIds) {
            val views = buildCompactRemoteViews(context, payload, nowMs)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    fun updateExpandedWidgets(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val payload = parsePayload(widgetData.getString(PAYLOAD_STORAGE_KEY, null))
        val nowMs = System.currentTimeMillis()
        for (widgetId in appWidgetIds) {
            val views = buildExpandedRemoteViews(context, payload, nowMs)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    internal fun buildCompactRemoteViews(
        context: Context,
        payload: ParsedWidgetPayload?,
        nowMs: Long,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.rail_widget_compact)
        val boardIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("$DEEP_LINK_SCHEME://board"),
        )
        views.setOnClickPendingIntent(R.id.widget_compact_root, boardIntent)

        if (payload == null) {
            views.setTextViewText(R.id.widget_compact_route, "Narayanganj Commuter")
            views.setTextViewText(R.id.widget_compact_eyebrow, "SCHEDULE WIDGET")
            views.setTextViewText(R.id.widget_compact_departure, "Tap to load")
            views.setTextViewText(R.id.widget_compact_arrival, "Open app to sync schedule")
            views.setViewVisibility(R.id.widget_compact_status, View.GONE)
            return views
        }

        val routeText = "${payload.boardingStationName} → ${payload.destinationStationName}"
        views.setTextViewText(R.id.widget_compact_route, routeText)

        if (payload.hasNextTrain &&
            payload.nextTrainNo != null &&
            !payload.nextDepartureTime.isNullOrEmpty()
        ) {
            views.setTextViewText(
                R.id.widget_compact_eyebrow,
                "NEXT TRAIN · #${payload.nextTrainNo}",
            )
            views.setTextViewText(R.id.widget_compact_departure, payload.nextDepartureTime)
            val arrivalCopy = if (!payload.nextArrivalTime.isNullOrEmpty()) {
                "Arrives ${payload.nextArrivalTime}"
            } else {
                "To ${payload.destinationStationName}"
            }
            views.setTextViewText(R.id.widget_compact_arrival, arrivalCopy)
        } else {
            views.setTextViewText(R.id.widget_compact_eyebrow, "NEXT TRAIN")
            views.setTextViewText(R.id.widget_compact_departure, "No upcoming train")
            views.setTextViewText(
                R.id.widget_compact_arrival,
                "No scheduled departures remaining",
            )
        }

        val statusCopy = resolveTimestampOrStaleLabel(payload, nowMs, showWhenFresh = false)
        if (statusCopy != null) {
            views.setTextViewText(R.id.widget_compact_status, statusCopy)
            views.setViewVisibility(R.id.widget_compact_status, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_compact_status, View.GONE)
        }

        return views
    }

    internal fun buildExpandedRemoteViews(
        context: Context,
        payload: ParsedWidgetPayload?,
        nowMs: Long,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.rail_widget_expanded)
        val boardIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("$DEEP_LINK_SCHEME://board"),
        )
        views.setOnClickPendingIntent(R.id.widget_expanded_root, boardIntent)

        if (payload == null) {
            views.setTextViewText(R.id.widget_expanded_route, "Narayanganj Commuter")
            views.setViewVisibility(R.id.widget_expanded_timestamp, View.GONE)
            views.setTextViewText(R.id.widget_expanded_eyebrow, "SCHEDULE WIDGET")
            views.setTextViewText(R.id.widget_expanded_departure, "Tap to load route")
            views.setTextViewText(
                R.id.widget_expanded_arrival,
                "Open app to sync your saved station",
            )
            views.setViewVisibility(R.id.widget_expanded_community_status, View.GONE)
            views.setViewVisibility(R.id.widget_expanded_report_strip, View.GONE)
            return views
        }

        val routeText = "${payload.boardingStationName} → ${payload.destinationStationName}"
        views.setTextViewText(R.id.widget_expanded_route, routeText)

        val timestampCopy = resolveTimestampOrStaleLabel(payload, nowMs, showWhenFresh = true)
        if (!timestampCopy.isNullOrEmpty()) {
            views.setTextViewText(R.id.widget_expanded_timestamp, timestampCopy)
            views.setViewVisibility(R.id.widget_expanded_timestamp, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_expanded_timestamp, View.GONE)
        }

        if (payload.hasNextTrain &&
            payload.nextTrainNo != null &&
            !payload.nextDepartureTime.isNullOrEmpty()
        ) {
            views.setTextViewText(
                R.id.widget_expanded_eyebrow,
                "NEXT TRAIN · #${payload.nextTrainNo}",
            )
            views.setTextViewText(R.id.widget_expanded_departure, payload.nextDepartureTime)
            val arrivalCopy = if (!payload.nextArrivalTime.isNullOrEmpty()) {
                "Arrives ${payload.destinationStationName} ${payload.nextArrivalTime}"
            } else {
                "To ${payload.destinationStationName}"
            }
            views.setTextViewText(R.id.widget_expanded_arrival, arrivalCopy)
        } else {
            views.setTextViewText(R.id.widget_expanded_eyebrow, "NEXT TRAIN")
            views.setTextViewText(R.id.widget_expanded_departure, "No upcoming train")
            views.setTextViewText(
                R.id.widget_expanded_arrival,
                "No scheduled departures remaining",
            )
        }

        val effectiveCommunityLabel = resolveEffectiveCommunityLabel(payload, nowMs)
        val primaryMatchesCommunity =
            effectiveCommunityLabel != null &&
                payload.hasNextTrain &&
                payload.nextTrainNo != null &&
                payload.communityTrainNo == payload.nextTrainNo
        if (primaryMatchesCommunity) {
            views.setTextViewText(R.id.widget_expanded_community_status, effectiveCommunityLabel)
            views.setViewVisibility(R.id.widget_expanded_community_status, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_expanded_community_status, View.GONE)
        }

        val showDistinctReportStrip =
            payload.hasReportTarget &&
                payload.reportTrainNo != null &&
                payload.reportTrainNo != payload.nextTrainNo
        if (showDistinctReportStrip) {
            val reportTrainNo = payload.reportTrainNo!!
            val titleText = if (!payload.reportScheduledDeparture.isNullOrEmpty()) {
                "Previous Train #$reportTrainNo · ${payload.reportScheduledDeparture}"
            } else {
                "Previous Train #$reportTrainNo"
            }
            views.setTextViewText(R.id.widget_expanded_report_title, titleText)

            val reportMatchesCommunity =
                effectiveCommunityLabel != null && payload.communityTrainNo == reportTrainNo
            if (reportMatchesCommunity) {
                views.setTextViewText(
                    R.id.widget_expanded_report_subtitle,
                    effectiveCommunityLabel,
                )
                views.setViewVisibility(R.id.widget_expanded_report_subtitle, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_expanded_report_subtitle, View.GONE)
            }

            val isStale = isPayloadStale(payload, nowMs)
            val actionEnabled = payload.isReportingAvailable && !isStale
            val actionLabel = payload.reportStatusLabel
                ?: if (actionEnabled) "Report arrival" else "Reporting unavailable"
            views.setTextViewText(R.id.widget_expanded_report_action, actionLabel)
            views.setInt(
                R.id.widget_expanded_report_action,
                "setBackgroundResource",
                if (actionEnabled) {
                    R.drawable.widget_action_active_bg
                } else {
                    R.drawable.widget_action_disabled_bg
                },
            )
            views.setTextColor(
                R.id.widget_expanded_report_action,
                ContextCompat.getColor(
                    context,
                    if (actionEnabled) {
                        R.color.widget_accent_fg
                    } else {
                        R.color.widget_text_secondary
                    },
                ),
            )

            val reportUri = Uri.Builder()
                .scheme(DEEP_LINK_SCHEME)
                .authority("report")
                .appendQueryParameter("trainNo", reportTrainNo.toString())
                .appendQueryParameter("direction", payload.direction)
                .appendQueryParameter("boardingStation", payload.boardingStationId)
                .build()
            val reportIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                reportUri,
            )
            views.setContentDescription(
                R.id.widget_expanded_report_strip,
                "Report arrival for Train #$reportTrainNo",
            )
            views.setOnClickPendingIntent(R.id.widget_expanded_report_strip, reportIntent)
            views.setViewVisibility(R.id.widget_expanded_report_strip, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_expanded_report_strip, View.GONE)
        }

        return views
    }

    internal fun isPayloadStale(payload: ParsedWidgetPayload, nowMs: Long): Boolean {
        val ageMs = (nowMs - payload.updatedAtEpochMs).coerceAtLeast(0L)
        if (payload.updatedAtEpochMs <= 0L || ageMs > STALE_PAYLOAD_THRESHOLD_MS) {
            return true
        }
        val nextEpoch = payload.nextDepartureEpochMs
        if (payload.hasNextTrain && nextEpoch != null && nextEpoch > 0L && nowMs > nextEpoch) {
            return true
        }
        return false
    }

    private fun resolveTimestampOrStaleLabel(
        payload: ParsedWidgetPayload,
        nowMs: Long,
        showWhenFresh: Boolean,
    ): String? {
        val stale = isPayloadStale(payload, nowMs)
        val baseLabel = payload.updatedAtLabel.trim()
        if (stale) {
            return if (baseLabel.isNotEmpty()) {
                "Stale · $baseLabel"
            } else {
                "Stale · Open app to refresh"
            }
        }
        if (!showWhenFresh) {
            return null
        }
        return baseLabel.ifEmpty { null }
    }

    private fun resolveEffectiveCommunityLabel(
        payload: ParsedWidgetPayload,
        nowMs: Long,
    ): String? {
        val rawLabel = payload.communityStatusLabel?.trim()
        if (rawLabel.isNullOrEmpty() ||
            payload.communityTripId.isNullOrEmpty() ||
            payload.communityTrainNo == null
        ) {
            return null
        }
        val ageMs = (nowMs - payload.updatedAtEpochMs).coerceAtLeast(0L)
        if (payload.updatedAtEpochMs <= 0L || ageMs > MAX_USABLE_COMMUNITY_WINDOW_MS) {
            return null
        }
        val shouldDowngradeToStale =
            ageMs > FRESH_COMMUNITY_WINDOW_MS || isPayloadStale(payload, nowMs)
        if (shouldDowngradeToStale && rawLabel.startsWith("Live · ")) {
            return "Stale · " + rawLabel.removePrefix("Live · ")
        }
        return rawLabel
    }

    internal fun parsePayload(rawJson: String?): ParsedWidgetPayload? {
        if (rawJson.isNullOrBlank()) {
            return null
        }
        return try {
            val json = JSONObject(rawJson)
            if (json.optInt("schemaVersion", -1) != EXPECTED_SCHEMA_VERSION) {
                return null
            }
            val direction = json.optString("direction", "").trim()
            val boardingStationId = json.optString("boardingStationId", "").trim()
            val boardingStationName = json.optString("boardingStationName", "").trim()
            val destinationStationId = json.optString("destinationStationId", "").trim()
            val destinationStationName = json.optString("destinationStationName", "").trim()
            if (direction.isEmpty() ||
                boardingStationId.isEmpty() ||
                boardingStationName.isEmpty() ||
                destinationStationId.isEmpty() ||
                destinationStationName.isEmpty()
            ) {
                return null
            }

            ParsedWidgetPayload(
                direction = direction,
                boardingStationId = boardingStationId,
                boardingStationName = boardingStationName,
                destinationStationId = destinationStationId,
                destinationStationName = destinationStationName,
                hasNextTrain = json.optBoolean("hasNextTrain", false),
                nextTrainNo = optNullableInt(json, "nextTrainNo"),
                nextDepartureTime = optNullableString(json, "nextDepartureTime"),
                nextArrivalTime = optNullableString(json, "nextArrivalTime"),
                nextDepartureEpochMs = optNullableLong(json, "nextDepartureEpochMs"),
                nextServicePeriod = optNullableString(json, "nextServicePeriod"),
                hasReportTarget = json.optBoolean("hasReportTarget", false),
                reportTrainNo = optNullableInt(json, "reportTrainNo"),
                reportScheduledDeparture = optNullableString(json, "reportScheduledDeparture"),
                isReportingAvailable = json.optBoolean("isReportingAvailable", false),
                reportStatusLabel = optNullableString(json, "reportStatusLabel"),
                communityTripId = optNullableString(json, "communityTripId"),
                communityTrainNo = optNullableInt(json, "communityTrainNo"),
                communityStatusLabel = optNullableString(json, "communityStatusLabel"),
                communityFreshness = optNullableString(json, "communityFreshness"),
                updatedAtEpochMs = json.optLong("updatedAtEpochMs", 0L),
                updatedAtLabel = json.optString("updatedAtLabel", ""),
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun optNullableString(json: JSONObject, key: String): String? {
        if (!json.has(key) || json.isNull(key)) {
            return null
        }
        val value = json.optString(key, "").trim()
        return value.ifEmpty { null }
    }

    private fun optNullableInt(json: JSONObject, key: String): Int? {
        if (!json.has(key) || json.isNull(key)) {
            return null
        }
        return json.optInt(key)
    }

    private fun optNullableLong(json: JSONObject, key: String): Long? {
        if (!json.has(key) || json.isNull(key)) {
            return null
        }
        return json.optLong(key)
    }
}

data class ParsedWidgetPayload(
    val direction: String,
    val boardingStationId: String,
    val boardingStationName: String,
    val destinationStationId: String,
    val destinationStationName: String,
    val hasNextTrain: Boolean,
    val nextTrainNo: Int?,
    val nextDepartureTime: String?,
    val nextArrivalTime: String?,
    val nextDepartureEpochMs: Long?,
    val nextServicePeriod: String?,
    val hasReportTarget: Boolean,
    val reportTrainNo: Int?,
    val reportScheduledDeparture: String?,
    val isReportingAvailable: Boolean,
    val reportStatusLabel: String?,
    val communityTripId: String?,
    val communityTrainNo: Int?,
    val communityStatusLabel: String?,
    val communityFreshness: String?,
    val updatedAtEpochMs: Long,
    val updatedAtLabel: String,
)
