package ru.nd.chtohochu

import android.Manifest
import android.content.pm.PackageManager
import android.provider.ContactsContract
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Плагин для чтения контактов через нативный ContactsContract.
/// Заменяет abandonware-пакет flutter_contacts.
class ContactsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private var binding: FlutterPlugin.FlutterPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        this.binding = binding
        channel = MethodChannel(binding.binaryMessenger, "ru.nd.chtohochu/contacts")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        this.binding = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getContactPhones" -> {
                val context = binding?.applicationContext
                if (context == null) {
                    result.error("NO_CONTEXT", "Context is null", null)
                    return
                }
                if (context.checkSelfPermission(Manifest.permission.READ_CONTACTS)
                    != PackageManager.PERMISSION_GRANTED
                ) {
                    result.error("PERMISSION_DENIED", "READ_CONTACTS not granted", null)
                    return
                }
                val phones = mutableListOf<Map<String, String>>()
                val cursor = context.contentResolver.query(
                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                    arrayOf(
                        ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                        ContactsContract.CommonDataKinds.Phone.NUMBER
                    ),
                    null,
                    null,
                    "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
                )
                cursor?.use {
                    val nameIdx = it.getColumnIndex(
                        ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME
                    )
                    val numberIdx = it.getColumnIndex(
                        ContactsContract.CommonDataKinds.Phone.NUMBER
                    )
                    while (it.moveToNext()) {
                        val name = if (nameIdx >= 0) it.getString(nameIdx) ?: "" else ""
                        val number = if (numberIdx >= 0) it.getString(numberIdx) ?: "" else ""
                        if (number.isNotBlank()) {
                            phones.add(mapOf("name" to name, "phone" to number))
                        }
                    }
                }
                result.success(phones)
            }
            else -> result.notImplemented()
        }
    }
}
