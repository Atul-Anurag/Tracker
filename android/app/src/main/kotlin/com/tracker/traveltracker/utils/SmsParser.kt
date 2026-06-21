package com.tracker.traveltracker.utils

import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.absoluteValue

data class ParsedTransaction(
    val amount: Double,
    val merchantName: String,
    val transactionTime: String,
    val upiVpa: String? = null,
    val referenceNumber: String? = null
)

/**
 * SMS Parser - Extracts transaction details from Indian bank SMS messages
 * Uses regex patterns to parse: Amount, Merchant, Time, UPI VPA, Reference Number
 */
object SmsParser {
    private const val TAG = "SmsParser"

    // Generic amount pattern (matches ₹, Rs, INR formats)
    private val amountPattern = Regex(r"(?:Rs[\.\s]?|₹|INR)[\s]*([0-9,]+(?:\.[0-9]{1,2})?)")
    
    // Merchant pattern (catches "at <Merchant>" or "to <Merchant>")
    private val merchantPattern = Regex(r"(?:at|to|from|@)\s+([A-Za-z0-9\s\-\.\,&']+?)(?:\s+(?:on|via|for|INR|RS|₹|UPI)|\s*$)")
    
    // Timestamp patterns
    private val dateTimePattern = Regex(r"(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?")
    private val timeOnlyPattern = Regex(r"(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(?:(AM|PM|am|pm))?")
    
    // VPA pattern for UPI
    private val vpaPattern = Regex(r"([a-zA-Z0-9\.\-_]+@[a-zA-Z]+)")
    
    // Reference/UTR pattern
    private val refPattern = Regex(r"(?:Ref|Reference|UTR|TXN)[\s#:]*([A-Z0-9]+)")
    
    // Keywords that indicate transaction SMS
    private val transactionKeywords = listOf(
        "debited", "credited", "debit", "credit", "INR", "UPI", 
        "transaction", "payment", "transferred", "received", "withdrawn"
    )

    // Merchants to exclude (not real transactions)
    private val excludedMerchants = listOf(
        "ATM", "balance", "mini statement", "branch", 
        "information", "charges", "interest", "fee"
    )

    /**
     * Main parsing function - Analyzes SMS and extracts transaction details
     */
    fun parseTransaction(smsText: String): ParsedTransaction? {
        // Check if SMS contains transaction keywords
        if (!isTransactionSms(smsText)) {
            return null
        }

        // Extract amount
        val amount = extractAmount(smsText) ?: return null

        // Extract merchant name
        val merchant = extractMerchant(smsText) ?: "Unknown Merchant"

        // Validate merchant (skip system messages)
        if (isExcludedMerchant(merchant)) {
            return null
        }

        // Extract transaction time
        val transactionTime = extractDateTime(smsText) ?: getCurrentTimeString()

        // Extract UPI VPA (if UPI transaction)
        val upiVpa = extractVPA(smsText)

        // Extract reference number
        val referenceNumber = extractReference(smsText)

        return ParsedTransaction(
            amount = amount,
            merchantName = merchant.trim(),
            transactionTime = transactionTime,
            upiVpa = upiVpa,
            referenceNumber = referenceNumber
        )
    }

    /**
     * Check if SMS contains transaction keywords
     */
    private fun isTransactionSms(smsText: String): Boolean {
        val lowerText = smsText.lowercase()
        return transactionKeywords.any { keyword ->
            lowerText.contains(keyword)
        }
    }

    /**
     * Extract amount from SMS
     */
    private fun extractAmount(smsText: String): Double? {
        val match = amountPattern.find(smsText) ?: return null
        val amountStr = match.groupValues[1].replace(",", "")
        return amountStr.toDoubleOrNull()
    }

    /**
     * Extract merchant name from SMS
     */
    private fun extractMerchant(smsText: String): String? {
        val match = merchantPattern.find(smsText) ?: return null
        return match.groupValues.getOrNull(1)?.trim()
    }

    /**
     * Extract date and time from SMS
     */
    private fun extractDateTime(smsText: String): String? {
        // Try full datetime pattern first
        val dateTimeMatch = dateTimePattern.find(smsText)
        if (dateTimeMatch != null) {
            val (day, month, year, hour, minute, second) = dateTimeMatch.destructured
            val fullYear = if (year.length == 2) "20$year" else year
            val sec = second.ifEmpty { "00" }
            return "$day/$month/$fullYear $hour:$minute:$sec"
        }

        // Try time-only pattern (assume today's date)
        val timeMatch = timeOnlyPattern.find(smsText)
        if (timeMatch != null) {
            val today = SimpleDateFormat("dd/MM/yyyy", Locale.getDefault()).format(Date())
            val (hour, minute, second, meridiem) = timeMatch.destructured
            val sec = second.ifEmpty { "00" }
            
            val adjustedHour = if (meridiem.isNotEmpty()) {
                val hourInt = hour.toIntOrNull() ?: 0
                when {
                    meridiem.uppercase() == "PM" && hourInt != 12 -> hourInt + 12
                    meridiem.uppercase() == "AM" && hourInt == 12 -> 0
                    else -> hourInt
                }
            } else {
                hour.toIntOrNull() ?: 0
            }
            
            return "$today ${String.format("%02d", adjustedHour)}:$minute:$sec"
        }

        return null
    }

    /**
     * Extract UPI VPA (Virtual Payment Address)
     */
    private fun extractVPA(smsText: String): String? {
        val match = vpaPattern.find(smsText) ?: return null
        return match.groupValues.getOrNull(1)
    }

    /**
     * Extract reference/UTR number
     */
    private fun extractReference(smsText: String): String? {
        val match = refPattern.find(smsText) ?: return null
        return match.groupValues.getOrNull(1)
    }

    /**
     * Check if merchant should be excluded
     */
    private fun isExcludedMerchant(merchant: String): Boolean {
        val lowerMerchant = merchant.lowercase()
        return excludedMerchants.any { excluded ->
            lowerMerchant.contains(excluded, ignoreCase = true)
        }
    }

    /**
     * Get current time in transaction format
     */
    private fun getCurrentTimeString(): String {
        val dateFormat = SimpleDateFormat("dd/MM/yyyy HH:mm:ss", Locale.getDefault())
        return dateFormat.format(Date())
    }
}
