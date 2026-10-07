package com.axlmly.kostori

import android.Manifest
import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Network
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.provider.OpenableColumns
import android.util.Log
import android.view.KeyEvent
import androidx.activity.result.ActivityResultCallback
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContract
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.documentfile.provider.DocumentFile
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import android.net.TrafficStats
import android.media.MediaScannerConnection
import android.os.StatFs
import dev.flutter.packages.file_selector_android.FileUtils
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.HttpURLConnection
import java.net.URL
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger
import java.util.Timer
import java.util.TimerTask
import com.ryanheise.audioservice.AudioServiceFragmentActivity

class MainActivity : AudioServiceFragmentActivity() {
    @Volatile private var torrentRelay: ServerSocket? = null
    @Volatile private var torrentUdpRelay: DatagramSocket? = null
    @Volatile private var torrentRelayAccepting = false
    @Volatile private var torrentUdpRelayRunning = false
    private val torrentRelayWorkers = Executors.newCachedThreadPool()
    var listening = false
    var volumeListen = VolumeListen()
    private val CHANNEL = "kostori/network_speed"
    private val ABI_CHANNEL = "kostori/abi"
    private val APK_CHANNEL = "kostori/install_apk"

    private val storageRequestCode = 0x10
    private var storagePermissionRequest: ((Boolean) -> Unit)? = null

    private val nextLocalRequestCode = AtomicInteger()

    private val sharedTexts = ArrayList<String>()

    private var textShareHandler: ((String) -> Unit)? = null

    private var pendingVideoIntent: String? = null
    private var videoIntentSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.action == Intent.ACTION_SEND) {
            if (intent.type == "text/plain") {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (text != null)
                    handleSharedText(text)
            }
        }
        handleVideoIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == Intent.ACTION_SEND) {
            if (intent.type == "text/plain") {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (text != null)
                    handleSharedText(text)
            }
        }
        handleVideoIntent(intent)
    }

    private fun handleVideoIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        val type = intent.type ?: contentResolver.getType(uri) ?: ""
        if (!type.startsWith("video/", ignoreCase = true)) return
        val raw = uri.toString()
        val sink = videoIntentSink
        if (sink == null) {
            pendingVideoIntent = raw
        } else {
            materializeVideoIntent(raw, sink)
        }
    }

    private fun materializeVideoIntent(
        rawUri: String,
        sink: EventChannel.EventSink,
    ) {
        torrentRelayWorkers.execute {
            val path = materializeVideoUri(rawUri)
            runOnUiThread {
                if (videoIntentSink === sink) {
                    sink.success(path)
                }
            }
        }
    }

    private fun materializeVideoUri(rawUri: String): String? {
        return try {
            val uri = Uri.parse(rawUri)
            when (uri.scheme?.lowercase()) {
                "file" -> uri.path
                "content" -> {
                    val name = contentResolver.query(
                        uri,
                        arrayOf(OpenableColumns.DISPLAY_NAME),
                        null,
                        null,
                        null,
                    )?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            cursor.getString(0)
                        } else {
                            null
                        }
                    }
                    val extension = name
                        ?.substringAfterLast('.', "")
                        ?.takeIf { it.matches(Regex("[A-Za-z0-9]{1,10}")) }
                    val suffix = if (extension == null) ".video" else ".$extension"
                    val dir = File(cacheDir, "external_videos")
                    if (!dir.exists()) dir.mkdirs()
                    val target = File(
                        dir,
                        "video_${System.currentTimeMillis()}$suffix",
                    )
                    contentResolver.openInputStream(uri)?.use { input ->
                        target.outputStream().use { output -> input.copyTo(output) }
                    } ?: return null
                    target.absolutePath
                }
                else -> File(rawUri).takeIf { it.exists() }?.absolutePath
            }
        } catch (error: Exception) {
            Log.e("Kostori", "materialize video failed: ${error.message}")
            null
        }
    }

    private fun consumePendingVideo(result: MethodChannel.Result) {
        val raw = pendingVideoIntent
        pendingVideoIntent = null
        if (raw == null) {
            result.success(null)
            return
        }
        torrentRelayWorkers.execute {
            val path = materializeVideoUri(raw)
            runOnUiThread { result.success(path) }
        }
    }

    private fun handleSharedText(text: String) {
        if (textShareHandler != null) {
            textShareHandler?.invoke(text)
        } else {
            sharedTexts.add(text)
        }
    }

    private fun <I, O> startContractForResult(
        contract: ActivityResultContract<I, O>,
        input: I,
        callback: ActivityResultCallback<O>
    ) {
        val key = "activity_rq_for_result#${nextLocalRequestCode.getAndIncrement()}"
        val registry = activityResultRegistry
        var launcher: ActivityResultLauncher<I>? = null
        val observer = object : LifecycleEventObserver {
            override fun onStateChanged(source: LifecycleOwner, event: Lifecycle.Event) {
                if (Lifecycle.Event.ON_DESTROY == event) {
                    launcher?.unregister()
                    lifecycle.removeObserver(this)
                }
            }
        }
        lifecycle.addObserver(observer)
        val newCallback = ActivityResultCallback<O> {
            launcher?.unregister()
            lifecycle.removeObserver(observer)
            callback.onActivityResult(it)
        }
        launcher = registry.register(key, contract, newCallback)
        launcher.launch(input)
    }

    private fun installApk(file: File) {
        val context = applicationContext
        val intent = Intent(Intent.ACTION_VIEW)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK

        val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            intent.flags = intent.flags or Intent.FLAG_GRANT_READ_URI_PERMISSION
            FileProvider.getUriForFile(context, "$packageName.fileprovider", file)
        } else {
            Uri.fromFile(file)
        }

        intent.setDataAndType(uri, "application/vnd.android.package-archive")
        context.startActivity(intent)
    }

    /// 用系统默认播放器打开本地视频（FileProvider content URI + ACTION_VIEW + mimeType）
    private fun openWithMime(path: String, mimeType: String) {
        val context = applicationContext
        val file = File(path)
        if (!file.exists()) return
        val intent = Intent(Intent.ACTION_VIEW)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
        val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            FileProvider.getUriForFile(context, "$packageName.fileprovider", file)
        } else {
            Uri.fromFile(file)
        }
        intent.setDataAndType(uri, mimeType)
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            // 没有能处理该 mimeType 的应用时忽略
            Log.e("Kostori", "openWithMime failed: ${e.message}")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // super 已通过 GeneratedPluginRegister.registerGeneratedPlugins 注册全部插件，
        // 这里不要再显式调 GeneratedPluginRegistrant.registerWith：
        // 既会重复注册，也会让本文件编译期依赖 Flutter 生成到
        // src/main/java 的那份文件（它可能残留 integration_test 引用）。
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kostori/external_intent",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialVideo" -> consumePendingVideo(result)
                else -> result.notImplemented()
            }
        }
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kostori/external_intent/events",
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                videoIntentSink = events
                val pending = pendingVideoIntent
                pendingVideoIntent = null
                if (pending != null && events != null) {
                    materializeVideoIntent(pending, events)
                }
            }

            override fun onCancel(arguments: Any?) {
                videoIntentSink = null
            }
        })
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kostori/method_channel"
        ).setMethodCallHandler { call, res ->
            when (call.method) {
                "getProxy" -> res.success(getProxy())
                "isVpnActive" -> {
                    val connectivity = getSystemService(ConnectivityManager::class.java)
                    res.success(connectivity.allNetworks.any { network ->
                        connectivity.getNetworkCapabilities(network)
                            ?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
                    })
                }
                "startTorrentDirectRelay" -> {
                    try {
                        val relay = torrentRelay ?: synchronized(this) {
                            torrentRelay ?: ServerSocket(0, 64, java.net.InetAddress.getByName("127.0.0.1"))
                                .also { torrentRelay = it }
                        }
                        if (relay.localPort > 0) {
                            if (!torrentRelayAccepting) synchronized(this) {
                                if (!torrentRelayAccepting) {
                                    torrentRelayAccepting = true
                                    torrentRelayWorkers.execute { acceptTorrentRelay(relay) }
                                }
                            }
                            res.success(relay.localPort)
                        } else {
                            res.error("TORRENT_RELAY", "Unable to bind local relay", null)
                        }
                    } catch (error: Exception) {
                        res.error("TORRENT_RELAY", error.message, null)
                    }
                }
                "announceTorrentHttpTracker" -> {
                    val rawUrl = call.argument<String>("url")
                    if (rawUrl.isNullOrBlank()) {
                        res.error("TORRENT_TRACKER", "url is empty", null)
                    } else {
                        torrentRelayWorkers.execute {
                            try {
                                val url = URL(rawUrl)
                                if (url.protocol != "http" && url.protocol != "https") {
                                    throw IllegalArgumentException("unsupported tracker protocol")
                                }
                                val physical = directTorrentNetwork()
                                    ?: throw java.io.IOException("no physical network available")
                                val connection = physical.openConnection(url) as HttpURLConnection
                                connection.connectTimeout = 12_000
                                connection.readTimeout = 12_000
                                connection.instanceFollowRedirects = false
                                connection.setRequestProperty("User-Agent", "Kostori/1.0")
                                connection.requestMethod = "GET"
                                val status = connection.responseCode
                                if (status != HttpURLConnection.HTTP_OK) {
                                    throw java.io.IOException("HTTP $status")
                                }
                                val output = ByteArrayOutputStream()
                                connection.inputStream.use { input ->
                                    val buffer = ByteArray(8192)
                                    while (true) {
                                        val count = input.read(buffer)
                                        if (count < 0) break
                                        output.write(buffer, 0, count)
                                        if (output.size() > 1024 * 1024) {
                                            throw java.io.IOException("tracker response too large")
                                        }
                                    }
                                }
                                connection.disconnect()
                                runOnUiThread { res.success(output.toByteArray()) }
                            } catch (error: Exception) {
                                runOnUiThread {
                                    res.error("TORRENT_TRACKER", error.message, null)
                                }
                            }
                        }
                    }
                }
                "startTorrentDirectUdpRelay" -> {
                    try {
                        val relay = torrentUdpRelay ?: synchronized(this) {
                            torrentUdpRelay ?: DatagramSocket(0, java.net.InetAddress.getByName("127.0.0.1"))
                                .also { torrentUdpRelay = it }
                        }
                        if (relay.localPort > 0) {
                            if (!torrentUdpRelayRunning) synchronized(this) {
                                if (!torrentUdpRelayRunning) {
                                    torrentUdpRelayRunning = true
                                    torrentRelayWorkers.execute { relayTorrentUdp(relay) }
                                }
                            }
                            res.success(relay.localPort)
                        } else {
                            res.error("TORRENT_UDP_RELAY", "Unable to bind local relay", null)
                        }
                    } catch (error: Exception) {
                        res.error("TORRENT_UDP_RELAY", error.message, null)
                    }
                }
                "openWithMime" -> {
                    val path = call.argument<String>("url") ?: ""
                    if (path.isNotEmpty()) {
                        openWithMime(path, call.argument<String>("mimeType") ?: "video/*")
                        res.success(true)
                    } else {
                        res.error("INVALID_PATH", "path is empty", null)
                    }
                }
                "setScreenOn" -> {
                    val set = call.argument<Boolean>("set") ?: false
                    if (set) {
                        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    res.success(null)
                }

                "startHubKeepAlive" -> {
                    HubKeepAliveService.start(applicationContext)
                    res.success(null)
                }

                "stopHubKeepAlive" -> {
                    HubKeepAliveService.stop(applicationContext)
                    res.success(null)
                }

                "startDownloadForeground" -> {
                    val rawTasks = call.argument<List<Map<String, Any>>>("tasks") ?: emptyList()
                    val remaining = (call.argument<Number>("remaining")?.toInt()) ?: rawTasks.size
                    DownloadForegroundService.start(applicationContext, rawTasks, remaining)
                    res.success(null)
                }

                "stopDownloadForeground" -> {
                    DownloadForegroundService.stop(applicationContext)
                    res.success(null)
                }

                "updateDownloadForeground" -> {
                    val rawTasks = call.argument<List<Map<String, Any>>>("tasks") ?: emptyList()
                    val remaining = (call.argument<Number>("remaining")?.toInt()) ?: rawTasks.size
                    DownloadForegroundService.update(applicationContext, rawTasks, remaining)
                    res.success(null)
                }

                "getDirectoryPath" -> {
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                    startContractForResult(ActivityResultContracts.StartActivityForResult(), intent) { activityResult ->
                        if (activityResult.resultCode != Activity.RESULT_OK) {
                            res.success(null)
                            return@startContractForResult
                        }
                        val pickedDirectoryUri = activityResult.data?.data
                        if (pickedDirectoryUri == null)
                            res.success(null)
                        else
                            onPickedDirectory(pickedDirectoryUri, res)
                    }
                }

                else -> res.notImplemented()
            }
        }

        val volumeChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "kostori/volume")
        volumeChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    listening = true
                    volumeListen.onUp = {
                        events.success(1)
                    }
                    volumeListen.onDown = {
                        events.success(2)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    listening = false
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ABI_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getAbi") {
                val abi = Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"
                result.success(abi)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APK_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val apkPath = call.argument<String>("apkPath")
                if (apkPath != null) {
                    installApk(File(apkPath))
                    result.success(null)
                } else {
                    result.error("INVALID_PATH", "APK path is null", null)
                }
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kostori/media"
        ).setMethodCallHandler { call, result ->
            if (call.method == "scanFolder") {
                val path = call.argument<String>("path")
                if (path != null) {
                    MediaScannerConnection.scanFile(this, arrayOf(path), null, null)
                    result.success("scanned")
                } else {
                    result.error("NO_PATH", "Path is null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        val storageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kostori/storage")
        storageChannel.setMethodCallHandler { call, res ->
            if (call.method == "getStorageInfo") {
                // 返回下载目录所在分区的总容量和可用空间。
                try {
                    val rawPath = call.argument<String>("path")
                    var dir = if (rawPath.isNullOrEmpty()) filesDir else File(rawPath)
                    if (!dir.exists()) dir = filesDir
                    val stat = StatFs(dir.absolutePath)
                    res.success(mapOf("free" to stat.availableBytes, "total" to stat.totalBytes))
                } catch (e: Exception) {
                    res.error("STATFS_FAIL", e.message, null)
                }
            } else if (call.method == "getFreeSpace") {
                // 下载目录剩余空间（StatFs，字节）：目录不存在时按 App 私有目录兜底
                try {
                    val rawPath = call.argument<String>("path")
                    var dir = if (rawPath.isNullOrEmpty()) filesDir else File(rawPath)
                    if (!dir.exists()) dir = filesDir
                    res.success(StatFs(dir.absolutePath).availableBytes)
                } catch (e: Exception) {
                    res.error("STATFS_FAIL", e.message, null)
                }
            } else {
                requestStoragePermission { result ->
                    res.success(result)
                }
            }
        }

        val selectFileChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kostori/select_file")
        selectFileChannel.setMethodCallHandler { req, res ->
            val mimeType = req.arguments<String>()
            openFile(res, mimeType!!)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getNetworkStats") {
                val uid = applicationContext.applicationInfo.uid
                val rxBytes = TrafficStats.getUidRxBytes(uid)
                val txBytes = TrafficStats.getUidTxBytes(uid)
                val stats = mapOf("rxBytes" to rxBytes, "txBytes" to txBytes)
                result.success(stats)
            } else {
                result.notImplemented()
            }
        }

    }

    private fun acceptTorrentRelay(server: ServerSocket) {
        while (!server.isClosed) {
            try {
                val local = server.accept()
                torrentRelayWorkers.execute { relayTorrentSocket(local) }
            } catch (_: Exception) {
                if (server.isClosed) return
            }
        }
    }

    private fun relayTorrentSocket(local: Socket) {
        var upstream: Socket? = null
        try {
            local.soTimeout = 15_000
            val input = DataInputStream(local.getInputStream())
            val hostLength = input.readUnsignedShort()
            if (hostLength == 0) return
            val hostBytes = ByteArray(hostLength)
            input.readFully(hostBytes)
            val host = hostBytes.toString(Charsets.UTF_8)
            val port = input.readUnsignedShort()
            if (port == 0) return
            val physical = directTorrentNetwork()
            val remote = if (physical != null) physical.socketFactory.createSocket() else Socket()
            if (physical != null) physical.bindSocket(remote)
            remote.connect(InetSocketAddress(host, port), 10_000)
            remote.soTimeout = 0
            upstream = remote
            local.soTimeout = 0
            val downstream = remote
            val a = torrentRelayWorkers.submit {
                copyStream(input, downstream.getOutputStream())
            }
            val b = torrentRelayWorkers.submit {
                copyStream(downstream.getInputStream(), local.getOutputStream())
            }
            try { a.get() } finally { downstream.close(); local.close(); b.cancel(true) }
        } catch (_: Exception) {
            try { local.close() } catch (_: Exception) { }
            try { upstream?.close() } catch (_: Exception) { }
        }
    }

    private fun copySocket(source: Socket, destination: Socket) {
        try {
            source.getInputStream().copyTo(destination.getOutputStream(), 64 * 1024)
            destination.shutdownOutput()
        } catch (_: Exception) { }
    }

    private fun copyStream(source: java.io.InputStream, destination: OutputStream) {
        try {
            source.copyTo(destination, 64 * 1024)
            destination.flush()
        } catch (_: Exception) { }
    }

    private fun relayTorrentUdp(server: DatagramSocket) {
        val buffer = ByteArray(65_535)
        while (!server.isClosed) {
            try {
                val request = DatagramPacket(buffer, buffer.size)
                server.receive(request)
                val bytes = request.data.copyOfRange(0, request.length)
                if (bytes.size < 4) continue
                val hostLength = ((bytes[0].toInt() and 0xff) shl 8) or
                    (bytes[1].toInt() and 0xff)
                if (hostLength <= 0 || bytes.size < hostLength + 4) continue
                val host = bytes.copyOfRange(2, 2 + hostLength).toString(Charsets.UTF_8)
                val portOffset = 2 + hostLength
                val port = ((bytes[portOffset].toInt() and 0xff) shl 8) or
                    (bytes[portOffset + 1].toInt() and 0xff)
                val payloadOffset = portOffset + 2
                if (port <= 0 || payloadOffset >= bytes.size) continue
                val physical = directTorrentNetwork() ?: continue
                val upstream = DatagramSocket()
                physical.bindSocket(upstream)
                upstream.soTimeout = 3_000
                upstream.send(DatagramPacket(
                    bytes,
                    payloadOffset,
                    bytes.size - payloadOffset,
                    InetSocketAddress(host, port),
                ))
                try {
                    while (true) {
                        val response = DatagramPacket(buffer, buffer.size)
                        upstream.receive(response)
                        server.send(DatagramPacket(
                            response.data,
                            response.length,
                            request.address,
                            request.port,
                        ))
                    }
                } catch (_: java.net.SocketTimeoutException) {
                    upstream.close()
                }
            } catch (_: Exception) {
                if (server.isClosed) return
            }
        }
    }

    private fun directTorrentNetwork(): Network? {
        val connectivity = getSystemService(ConnectivityManager::class.java)
        val candidates = connectivity.allNetworks.mapNotNull { network ->
            val capabilities = connectivity.getNetworkCapabilities(network) ?: return@mapNotNull null
            if (!capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) ||
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) return@mapNotNull null
            val rank = when {
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> 0
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> 1
                else -> 2
            }
            Triple(rank, network, capabilities)
        }.sortedBy { it.first }
        return candidates.firstOrNull()?.second
    }

    override fun onDestroy() {
        try { torrentRelay?.close() } catch (_: Exception) { }
        try { torrentUdpRelay?.close() } catch (_: Exception) { }
        torrentRelayWorkers.shutdownNow()
        super.onDestroy()
    }

    private fun getProxy(): String {
        val host = System.getProperty("http.proxyHost")
        val port = System.getProperty("http.proxyPort")
        return if (host != null && port != null) {
            "$host:$port"
        } else {
            "No Proxy"
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (listening) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    volumeListen.down()
                    return true
                }

                KeyEvent.KEYCODE_VOLUME_UP -> {
                    volumeListen.up()
                    return true
                }
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    /// Ensure that the directory is accessible by dart:io
    private fun onPickedDirectory(uri: Uri, result: MethodChannel.Result) {
        if (hasStoragePermission()) {
            var plain = uri.toString()
            if (plain.contains("%3A")) {
                plain = Uri.decode(plain)
            }
            val externalStoragePrefix = "content://com.android.externalstorage.documents/tree/primary:";
            if (plain.startsWith(externalStoragePrefix)) {
                val path = plain.substring(externalStoragePrefix.length)
                result.success(Environment.getExternalStorageDirectory().absolutePath + "/" + path)
            }
            // The uri cannot be parsed to plain path, use copy method
        }
        // dart:io cannot access the directory without permission.
        // so we need to copy the directory to cache directory
        val contentResolver = contentResolver
        var tmp = cacheDir
        var dirName = DocumentFile.fromTreeUri(this, uri)?.name
        tmp = File(tmp, dirName!!)
        if (tmp.exists()) {
            tmp.deleteRecursively()
        }
        tmp.mkdir()
        Thread {
            try {
                copyDirectory(contentResolver, uri, tmp)
                result.success(tmp.absolutePath)
            } catch (e: Exception) {
                result.error("copy error", e.message, null)
            }
        }.start()

    }

    private fun copyDirectory(resolver: ContentResolver, srcUri: Uri, destDir: File) {
        val src = DocumentFile.fromTreeUri(this, srcUri) ?: return
        for (file in src.listFiles()) {
            if (file.isDirectory) {
                val newDir = File(destDir, file.name!!)
                newDir.mkdir()
                copyDirectory(resolver, file.uri, newDir)
            } else {
                val newFile = File(destDir, file.name!!)
                resolver.openInputStream(file.uri)?.use { input ->
                    FileOutputStream(newFile).use { output ->
                        input.copyTo(output, bufferSize = DEFAULT_BUFFER_SIZE)
                        output.flush()
                    }
                }
            }
        }
    }

    private fun hasStoragePermission(): Boolean {
        return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED && ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            Environment.isExternalStorageManager()
        }
    }

    private fun requestStoragePermission(result: (Boolean) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            val readPermission = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED

            val writePermission = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED

            if (!readPermission || !writePermission) {
                storagePermissionRequest = result
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(
                        Manifest.permission.READ_EXTERNAL_STORAGE,
                        Manifest.permission.WRITE_EXTERNAL_STORAGE
                    ),
                    storageRequestCode
                )
            } else {
                result(true)
            }
        } else {
            if (!Environment.isExternalStorageManager()) {
                try {
                    val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                    intent.addCategory("android.intent.category.DEFAULT")
                    intent.data = Uri.parse("package:$packageName")
                    startContractForResult(ActivityResultContracts.StartActivityForResult(), intent) { _ ->
                        result(Environment.isExternalStorageManager())
                    }
                } catch (e: Exception) {
                    result(false)
                }
            } else {
                result(true)
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == storageRequestCode) {
            storagePermissionRequest?.invoke(grantResults.all {
                it == PackageManager.PERMISSION_GRANTED
            })
            storagePermissionRequest = null
        }
    }

    private fun openFile(result: MethodChannel.Result, mimeType: String) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
        intent.addCategory(Intent.CATEGORY_OPENABLE)
        intent.type = mimeType
        startContractForResult(ActivityResultContracts.StartActivityForResult(), intent) { activityResult ->
            if (activityResult.resultCode != Activity.RESULT_OK) {
                result.success(null)
                return@startContractForResult
            }
            val uri = activityResult.data?.data
            if (uri == null) {
                result.success(null)
                return@startContractForResult
            }
            val contentResolver = contentResolver
            val file = DocumentFile.fromSingleUri(this, uri)
            if (file == null) {
                result.success(null)
                return@startContractForResult
            }
            val fileName = file.name
            if (fileName == null) {
                result.success(null)
                return@startContractForResult
            }
            if (hasStoragePermission()) {
                try {
                    val filePath = FileUtils.getPathFromUri(this, uri)
                    result.success(filePath)
                    return@startContractForResult
                } catch (e: Exception) {
                    // ignore
                }
            }
            // use copy method
            val tmp = File(cacheDir, fileName)
            if (tmp.exists()) {
                tmp.delete()
            }
            Log.i("Kostori", "copy file (${fileName}) to ${tmp.absolutePath}")
            Thread {
                try {
                    contentResolver.openInputStream(uri)?.use { input ->
                        FileOutputStream(tmp).use { output ->
                            input.copyTo(output, bufferSize = DEFAULT_BUFFER_SIZE)
                            output.flush()
                        }
                    }
                    result.success(tmp.absolutePath)
                } catch (e: Exception) {
                    result.error("copy error", e.message, null)
                }
            }.start()
        }
    }
}

class VolumeListen {
    var onUp = fun() {}
    var onDown = fun() {}
    fun up() {
        onUp()
    }

    fun down() {
        onDown()
    }
}
