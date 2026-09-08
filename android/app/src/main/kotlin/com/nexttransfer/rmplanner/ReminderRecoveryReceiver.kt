package com.nexttransfer.rmplanner

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import dev.fluttercommunity.workmanager.BackgroundWorker

/** Broadcasts enqueue one bounded canonical recovery; they never start a service. */
class ReminderRecoveryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in setOf(
                Intent.ACTION_BOOT_COMPLETED,
                Intent.ACTION_MY_PACKAGE_REPLACED,
                Intent.ACTION_TIME_CHANGED,
                Intent.ACTION_TIMEZONE_CHANGED,
            )) return
        val request = OneTimeWorkRequestBuilder<BackgroundWorker>()
            .setInputData(Data.Builder()
                .putString(BackgroundWorker.DART_TASK_KEY, "nt.reminder.recovery")
                .build())
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            "nt.reminder.recovery", ExistingWorkPolicy.REPLACE, request)
    }
}
