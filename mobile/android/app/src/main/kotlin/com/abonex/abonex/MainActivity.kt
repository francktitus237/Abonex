package com.abonex.abonex

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

// FlutterFragmentActivity (et non FlutterActivity) est OBLIGATOIRE
// pour local_auth : la boîte de dialogue biométrique Android est un
// Fragment, elle ne peut pas s'afficher sur une FlutterActivity simple.
class MainActivity : FlutterFragmentActivity() {

    /// Le son d'alarme importé doit vivre dans le MediaStore :
    /// c'est le SystemUI qui le joue, et il ne peut PAS lire les
    /// fichiers privés de l'app (d'où les sonneries muettes en
    /// file://). Une URI content:// MediaStore est lisible par tous.
    private val channelName = "abonex/media_store"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "importSound" -> {
                        val path = call.argument<String>("path")
                        val name = call.argument<String>("name") ?: "alarm"
                        if (path.isNullOrEmpty()) {
                            result.error("ARG", "path manquant", null)
                        } else {
                            try {
                                result.success(importToMediaStore(path, name))
                            } catch (e: Exception) {
                                result.error("IMPORT", e.message, null)
                            }
                        }
                    }
                    "deleteSound" -> {
                        val uri = call.argument<String>("uri")
                        try {
                            if (!uri.isNullOrEmpty() && uri.startsWith("content://")) {
                                contentResolver.delete(android.net.Uri.parse(uri), null, null)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("DELETE", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Copie le fichier privé dans MediaStore.Audio (Music/Abonex)
    /// et retourne l'URI content:// à utiliser comme sonnerie.
    private fun importToMediaStore(path: String, name: String): String {
        val src = File(path)
        if (!src.exists()) throw IllegalArgumentException("fichier introuvable")
        val ext = src.extension.ifEmpty { "mp3" }.lowercase()
        val mime = when (ext) {
            "mp3" -> "audio/mpeg"
            "wav" -> "audio/wav"
            "ogg" -> "audio/ogg"
            "m4a", "aac" -> "audio/aac"
            "flac" -> "audio/flac"
            else -> "audio/*"
        }
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, "abonex_$name.$ext")
            put(MediaStore.Audio.Media.MIME_TYPE, mime)
            put(MediaStore.Audio.Media.IS_ALARM, 1)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Audio.Media.RELATIVE_PATH, "Music/Abonex")
                put(MediaStore.Audio.Media.IS_PENDING, 1)
            }
        }
        val resolver = applicationContext.contentResolver
        val uri = resolver.insert(collection, values)
            ?: throw IllegalStateException("insertion MediaStore refusée")
        try {
            resolver.openOutputStream(uri)?.use { out ->
                FileInputStream(src).use { it.copyTo(out) }
            } ?: throw IllegalStateException("écriture impossible")
        } catch (e: Exception) {
            // Nettoyage de la ligne orpheline si la copie échoue.
            resolver.delete(uri, null, null)
            throw e
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Audio.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }
        return uri.toString()
    }
}
