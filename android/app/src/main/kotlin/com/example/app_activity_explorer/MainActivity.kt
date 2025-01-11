package com.example.app_activity_explorer

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app_activity_explorer/channel"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger!!, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledAppsPaged" -> {
                    val startIndex = call.argument<Int>("startIndex") ?: 0
                    val limit = call.argument<Int>("limit") ?: 50
                    val showSystemApps = call.argument<Boolean>("showSystemApps") ?: true
                    result.success(getInstalledApps(startIndex, limit, showSystemApps))
                }
                "getAllActivities" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val showUnexported = call.argument<Boolean>("showUnexported") ?: true
                    result.success(getAllActivities(packageName, showUnexported))
                }
                "launchActivity" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val activityName = call.argument<String>("activityName") ?: ""
                    launchActivity(packageName, activityName)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getInstalledApps(startIndex: Int, limit: Int, showSystemApps: Boolean): List<Map<String, Any>> {
        val pm = packageManager
        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val filteredApps = apps.filter { app ->
            showSystemApps || app.flags and ApplicationInfo.FLAG_SYSTEM == 0
        }.sortedBy { pm.getApplicationLabel(it).toString() }

        val pagedApps = filteredApps.drop(startIndex).take(limit)
        return pagedApps.map { app ->
            mapOf(
                "appName" to pm.getApplicationLabel(app).toString(),
                "packageName" to app.packageName
            )
        }
    }

    private fun getAllActivities(packageName: String, showUnexported: Boolean): List<Map<String, Any>> {
        val pm = packageManager
        val activities = mutableListOf<Map<String, Any>>()
        try {
            val packageInfo = pm.getPackageInfo(
                packageName,
                PackageManager.GET_ACTIVITIES or PackageManager.MATCH_DISABLED_COMPONENTS
            )
            packageInfo.activities?.forEach { activity ->
                if (showUnexported || activity.exported) {
                  val activityLabel = activity.loadLabel(pm).toString() // 获取活动的 label（备注）
                    activities.add(
                        mapOf(
                            "name" to activity.name,
                            "label" to activityLabel, // 添加 label
                            "exported" to activity.exported.toString()
                        )
                    )
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return activities
    }

    private fun launchActivity(packageName: String, activityName: String) {
        try {
            val intent = Intent()
            intent.setClassName(packageName, activityName)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}