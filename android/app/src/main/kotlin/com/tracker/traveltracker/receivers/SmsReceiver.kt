package com.tracker.traveltracker.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.util.Log
import com.tracker.traveltracker.services.TransactionListenerService
import com.tracker.traveltracker.utils.SmsParser

/**
 * SMS BroadcastReceiver - Intercepts incoming SMS messages
 * Filters for transaction alerts from Indian banks
 * Triggers location capture on detected transactions
 */
class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SmsReceiver"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            return
        }

        context ?: return

        // Extract SMS messages from intent
        val pdus = intent.getParcelableArrayExtra(Telephony.Sms.Intents.SMS_PDU_EXTRA)
        pdus?.let {
            try {
                for (pdu in it) {
                    val sms = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                    sms?.let { messages ->
                        for (message in messages) {
                            val sender = message.originatingAddress ?: return@let
                            val messageBody = message.messageBody ?: return@let

                            Log.d(TAG, "SMS Received from: $sender")
                            Log.d(TAG, "Message: $messageBody")

                            // Parse the SMS to extract transaction details
                            val transaction = SmsParser.parseTransaction(messageBody)

                            if (transaction != null) {
                                Log.d(TAG, "Transaction parsed: $transaction")

                                // Send broadcast to TransactionListenerService to capture location
                                val locationIntent = Intent(context, TransactionListenerService::class.java)
                                locationIntent.action = "com.tracker.CAPTURE_LOCATION"
                                locationIntent.putExtra("transaction_data", transaction)

                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    context.startForegroundService(locationIntent)
                                } else {
                                    context.startService(locationIntent)
                                }

                                // Also send broadcast to Flutter/Dart layer for UI updates
                                val broadcastIntent = Intent("com.tracker.TRANSACTION_RECEIVED")
                                broadcastIntent.putExtra("amount", transaction.amount)
                                broadcastIntent.putExtra("merchant", transaction.merchantName)
                                broadcastIntent.putExtra("time", transaction.transactionTime)
                                broadcastIntent.putExtra("raw_sms", messageBody)

                                context.sendBroadcast(broadcastIntent)
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing SMS: ${e.message}", e)
            }
        }
    }
}
