package com.axlmly.kostori

import android.Manifest
import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
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
import dev.flutter.packages.file_selector_android.FileUtils
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicInteger
import java.util.Timer
import java.util.TimerTask
import com.ryanheise.audioservice.AudioServiceFragmentActivity

class MainActivity : AudioServiceFragmentActivity() {
    var volumeListen = VolumeListen()
    var listening = false

    private val CHANNEL = "kostori/network_speed"
    private val ABI_CHANNEL = "kostori/abi"
    private val APK_CHANNEL = "kostori/install_apk"

    private val storageRequestCode = 0x10
    private var storagePermissionRequest: ((Boolean) -> Unit)? = null

    private val nextLocalRequestCode = AtomicInteger()

    private val sharedTexts = ArrayList<String>()

    private var textShareHandler: ((String) -> Unit)? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.action == Intent.ACTION_SEND) {
            if (intent.type == "text/plain") {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (text != null)
                    handleSharedText(text)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == Intent.ACTION_SEND) {
            if (intent.type == "text/plain") {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (text != null)
                    handleSharedText(text)
            }
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kostori/method_channel"
        ).setMethodCallHandler { call, res ->
            when (call.method) {
                "getProxy" -> res.success(getProxy())
                "setScreenOn" -> {
                    val set = call.argument<Boolean>("set") ?: false
                    if (set) {
                        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
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

        val channel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "kostori/volume")
        channel.setStreamHandler(
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

        val storageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kostori/storage")
        storageChannel.setMethodCallHandler { _, res ->
            requestStoragePermission { result ->
                res.success(result)
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

