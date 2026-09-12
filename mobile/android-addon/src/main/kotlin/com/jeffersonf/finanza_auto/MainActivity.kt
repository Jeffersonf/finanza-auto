package com.jeffersonf.finanza_auto

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.jeffersonf.finanza_auto/updater"
    private var pendingAction: String? = null

    override fun onResume() {
        super.onResume()
        if (intent?.action == "ACTION_QUICK_FUEL") {
            pendingAction = "ACTION_QUICK_FUEL"
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == "ACTION_QUICK_FUEL") {
            pendingAction = "ACTION_QUICK_FUEL"
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (intent?.action == "ACTION_QUICK_FUEL") {
            pendingAction = "ACTION_QUICK_FUEL"
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingAction" -> {
                    val act = pendingAction
                    pendingAction = null
                    result.success(act)
                }
                "canRequestPackageInstalls" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "openInstallPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } else {
                        result.success(true)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrBlank()) {
                        result.error("INVALID_PATH", "O_caminho_do_APK_e_invalido", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "Arquivo APK-nao encontrado em $filePath", null)
                            return@setMethodCallHandler
                        }
                        val contentUri = FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(contentUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                "pickAndRecognizeImage" -> {
                    pendingOcrResult = result
                    try {
                        val intent = Intent(Intent.ACTION_PICK).apply {
                            type = "image/*"
                        }
                        startActivityForResult(intent, REQ_PICK_IMAGE)
                    } catch (e: Exception) {
                        pendingOcrResult?.error("PICK_ERROR", e.message, null)
                        pendingOcrResult = null
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_PICK_IMAGE) {
            val pending = pendingOcrResult
            pendingOcrResult = null
            if (resultCode == RESULT_OK && data?.data != null) {
                val imageUri: Uri = data.data!!
                try {
                    val image = com.google.mlkit.vision.common.InputImage.fromFilePath(this, imageUri)
                    val recognizer = com.google.mlkit.vision.text.TextRecognition.getClient(
                        com.google.mlkit.vision.text.latin.TextRecognizerOptions.DEFAULT_OPTIONS
                    )
                    recognizer.process(image)
                        .addOnSuccessListener { visionText ->
                            pending?.success(visionText.text)
                        }
                        .addOnFailureListener { e ->
                            pending?.error("OCR_ERROR", e.message, null)
                        }
                } catch (e: Exception) {
                    pending?.error("OCR_EXCEPTION", e.message, null)
                }
            } else {
                pending?.success(null)
            }
        }
    }

    companion object {
        private const val REQ_PICK_IMAGE = 1001
    }
    private var pendingOcrResult: MethodChannel.Result? = null
}

