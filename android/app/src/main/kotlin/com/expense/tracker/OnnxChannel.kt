package com.expense.tracker

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.LongBuffer
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

class OnnxChannel(private val context: Context, messenger: BinaryMessenger) {

    private val channel = MethodChannel(messenger, "com.expense.tracker/onnx")
    private val env = OrtEnvironment.getEnvironment()
    private val lock = ReentrantLock()
    private var session: OrtSession? = null
    private var loaded = false

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    Thread { result.success(loadModelSync()) }.start()
                }
                "runInference" -> {
                    val inputIds = call.argument<List<Int>>("input_ids") ?: emptyList()
                    val maxNewTokens = call.argument<Int>("max_new_tokens") ?: 60
                    runInference(inputIds, maxNewTokens, result)
                }
                else -> result.notImplemented()
            }
        }
        Thread { loadModelSync() }.start()
    }

    private fun loadModelSync(): Boolean {
        lock.withLock {
            if (loaded) return true
            return try {
                val dir = File(context.cacheDir, "models")
                if (!dir.exists()) dir.mkdirs()
                val modelFile = File(dir, "model.onnx")
                if (!modelFile.exists()) {
                    context.assets.open("flutter_assets/assets/model/model.onnx").use { input ->
                        modelFile.outputStream().use { output -> input.copyTo(output) }
                    }
                }
                val options = OrtSession.SessionOptions()
                options.setIntraOpNumThreads(4)
                session = env.createSession(modelFile.absolutePath, options)
                loaded = true
                Log.i("OnnxChannel", "model loaded from ${modelFile.absolutePath}")
                true
            } catch (e: Exception) {
                Log.e("OnnxChannel", "model load failed", e)
                false
            }
        }
    }

    private fun runInference(inputIds: List<Int>, maxNewTokens: Int, result: MethodChannel.Result) {
        Thread {
            try {
                val s = lock.withLock {
                    if (!loaded) loadModelSync()
                    session
                } ?: throw IllegalStateException("model not loaded")

                val generated = ArrayList<Int>()
                val seq = ArrayList<Long>(inputIds.size + maxNewTokens)
                inputIds.forEach { seq.add(it.toLong()) }

                for (step in 0 until maxNewTokens) {
                    val lastLogits = forward(s, seq)
                    var bestId = 0L
                    var best = Float.NEGATIVE_INFINITY
                    for (i in lastLogits.indices) {
                        if (lastLogits[i] > best) {
                            best = lastLogits[i]
                            bestId = i.toLong()
                        }
                    }
                    if (bestId == EOS_TOKEN_ID || bestId == END_TURN_TOKEN_ID) break
                    generated.add(bestId.toInt())
                    seq.add(bestId)
                }
                result.success(generated)
            } catch (e: Exception) {
                result.error("ONNX_ERROR", e.message, null)
            }
        }.start()
    }

    private fun forward(session: OrtSession, seq: List<Long>): FloatArray {
        val n = seq.size
        val inputIds = LongBuffer.wrap(seq.toLongArray())
        val mask = LongArray(n) { 1L }
        val maskBuf = LongBuffer.wrap(mask)
        val shape = longArrayOf(1, n.toLong())

        val inputTensor = OnnxTensor.createTensor(env, inputIds, shape)
        val maskTensor = OnnxTensor.createTensor(env, maskBuf, shape)
        try {
            session.run(
                mapOf(
                    "input_ids" to inputTensor,
                    "attention_mask" to maskTensor
                )
            ).use { outputs ->
                val logits = outputs[0].value as Array<Array<FloatArray>>
                return logits[0][n - 1].copyOf()
            }
        } finally {
            inputTensor.close()
            maskTensor.close()
        }
    }

    companion object {
        private const val EOS_TOKEN_ID = 1L
        private const val END_TURN_TOKEN_ID = 106L
    }
}
