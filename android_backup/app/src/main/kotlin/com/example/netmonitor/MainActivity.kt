package com.example.netmonitor

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.content.pm.PackageManager
import android.Manifest
import android.text.format.Formatter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "netmonitor/wifi"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "getWifiInfo") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                    val network = cm.activeNetwork
                    val caps = cm.getNetworkCapabilities(network)
                    val isWifi = caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
                    if (!isWifi) {
                        result.success(mapOf("ssid" to "Tidak terhubung ke WiFi", "rssi" to null, "ip" to "-"))
                        return@setMethodCallHandler
                    }
                    val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                    @Suppress("DEPRECATION")
                    val info = wm.connectionInfo
                    val hasLocation = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                        checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    val rawSsid = if (hasLocation) info.ssid?.replace("\"", "") else "Izin lokasi diperlukan"
                    val ssid = if (rawSsid.isNullOrBlank() || rawSsid == "<unknown ssid>") "SSID tidak tersedia" else rawSsid
                    val rssi = info.rssi.takeIf { it in -100..0 }
                    val ip = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        cm.getLinkProperties(network)?.linkAddresses
                            ?.firstOrNull { it.address is java.net.Inet4Address }?.address?.hostAddress ?: "-"
                    } else {
                        @Suppress("DEPRECATION")
                        val address = info.ipAddress
                        if (address == 0) "-" else Formatter.formatIpAddress(address)
                    }
                    result.success(mapOf("ssid" to ssid, "rssi" to rssi, "ip" to ip))
                } catch (e: Exception) {
                    result.success(mapOf("ssid" to "Tidak tersedia", "rssi" to null, "ip" to "-"))
                }
            }
    }
}
