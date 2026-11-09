package com.team8.campus_mini_feed

import android.os.BatteryManager
import android.os.Build
import android.os.Debug
import android.os.PowerManager
import android.view.WindowManager
import com.google.common.util.concurrent.ListenableFuture
import com.google.mlkit.genai.common.DownloadCallback
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.common.GenAiException
import com.google.mlkit.genai.proofreading.Proofreader
import com.google.mlkit.genai.proofreading.ProofreaderOptions
import com.google.mlkit.genai.proofreading.Proofreading
import com.google.mlkit.genai.proofreading.ProofreadingRequest
import com.google.mlkit.genai.prompt.GenerateContentRequest
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.java.GenerativeModelFutures
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executor

class MainActivity : FlutterActivity() {
    private val uiExecutor = Executor { runOnUiThread(it) }
    private var proofreader: Proofreader? = null
    private var model: GenerativeModel? = null
    private var generator: GenerativeModelFutures? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "campus_mini_feed/proofreader")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "status" -> proofreader().checkFeatureStatus().deliver(result, ::statusName)
                        "tokenizerStatus" -> generator().checkStatus().deliver(result, ::statusName)
                        "prepare" -> proofreader().prepareInferenceEngine().deliver(result) { null }
                        "downloadProofreader" -> proofreader().downloadFeature(noProgress).deliver(result) { null }
                        "downloadTokenizer" -> generator().download(noProgress).deliver(result) { null }
                        "baseModel" -> proofreader().baseModelName.deliver(result) { it }
                        "proofread" -> proofreader()
                            .runInference(
                                ProofreadingRequest.builder(call.argument<String>("text").orEmpty()).build(),
                            )
                            .deliver(result) { output -> output.results.map { it.text } }
                        "countTokens" -> generator()
                            .countTokens(
                                GenerateContentRequest.Builder(TextPart(call.argument<String>("text").orEmpty()))
                                    .build(),
                            )
                            .deliver(result) { it.totalTokens }
                        // Debug.getMemoryInfo can be slow; keep it off the UI thread
                        // that also delivers inference results.
                        "metrics" -> Thread {
                            val value = runCatching { metrics() }
                            runOnUiThread {
                                value.fold({ result.success(it) }, { fail(result, it) })
                            }
                        }.start()
                        "keepScreenOn" -> {
                            if (call.argument<Boolean>("on") == true) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            }
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    fail(result, error)
                }
            }
    }

    override fun onDestroy() {
        proofreader?.close()
        proofreader = null
        model?.close()
        model = null
        generator = null
        super.onDestroy()
    }

    private fun proofreader(): Proofreader = proofreader ?: Proofreading.getClient(
        ProofreaderOptions.builder(this)
            .setInputType(ProofreaderOptions.InputType.KEYBOARD)
            .setLanguage(ProofreaderOptions.Language.KOREAN)
            .build(),
    ).also { proofreader = it }

    private fun generator(): GenerativeModelFutures = generator
        ?: GenerativeModelFutures.from(Generation.getClient().also { model = it })
            .also { generator = it }

    private val noProgress = object : DownloadCallback {
        override fun onDownloadStarted(bytesToDownload: Long) {}
        override fun onDownloadProgress(totalBytesDownloaded: Long) {}
        override fun onDownloadCompleted() {}
        override fun onDownloadFailed(e: GenAiException) {}
    }

    private fun statusName(status: Int): String = when (status) {
        FeatureStatus.AVAILABLE -> "available"
        FeatureStatus.DOWNLOADABLE -> "downloadable"
        FeatureStatus.DOWNLOADING -> "downloading"
        else -> "unavailable"
    }

    private fun <T> ListenableFuture<T>.deliver(
        result: MethodChannel.Result,
        map: (T) -> Any?,
    ) {
        addListener({
            val value = try {
                map(get())
            } catch (error: ExecutionException) {
                fail(result, error.cause ?: error)
                return@addListener
            } catch (error: Exception) {
                fail(result, error)
                return@addListener
            }
            result.success(value)
        }, uiExecutor)
    }

    private fun fail(result: MethodChannel.Result, error: Throwable) {
        val code = (error as? GenAiException)?.errorCode?.toString() ?: "UNKNOWN"
        result.error(code, error.message, null)
    }

    // Measures this app process only; Gemini Nano runs inside the AICore process.
    private fun metrics(): Map<String, Any?> {
        val memory = Debug.MemoryInfo().also { Debug.getMemoryInfo(it) }
        val battery = getSystemService(BatteryManager::class.java)
        val power = getSystemService(PowerManager::class.java)
        val chargeCounter = battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
        return mapOf(
            "pssKb" to memory.totalPss,
            "thermalStatus" to
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) power.currentThermalStatus else null,
            "chargeCounterUah" to chargeCounter.takeIf { it > 0 },
            // Unsupported devices report 0 or Integer.MIN_VALUE.
            "batteryPercent" to
                battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY).takeIf { it in 1..100 },
            "charging" to battery.isCharging,
            "device" to "${Build.MANUFACTURER} ${Build.MODEL}",
            "sdk" to Build.VERSION.SDK_INT,
        )
    }
}
