package dev.repro.hcpp_leak

import android.content.Context
import android.os.Bundle
import android.view.SurfaceView
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Minimal reproduction: one ExoPlayer rendering into a SurfaceView that lives
 * in a Flutter platform view. Dart asks for a new media item every few
 * seconds; the player and the surface are never recreated.
 */
class MainActivity : FlutterActivity() {
    private var player: ExoPlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The run is unattended for half an hour.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val exo = ExoPlayer.Builder(this).build().also { player = it }

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "repro/video",
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
                    VideoView(context, exo)
            },
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "repro/player")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "play" -> {
                        // Same player, same surface: only the media changes.
                        exo.setMediaItem(MediaItem.fromUri(call.argument<String>("url")!!))
                        exo.prepare()
                        exo.playWhenReady = true
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        player?.release()
        player = null
        super.onDestroy()
    }
}

/** A SurfaceView the player renders into, attached once. */
private class VideoView(context: Context, private val player: ExoPlayer) : PlatformView {
    private val surfaceView = SurfaceView(context)
    private val root = FrameLayout(context).apply { addView(surfaceView) }

    init {
        player.setVideoSurfaceView(surfaceView)
    }

    override fun getView(): View = root

    override fun dispose() {
        player.clearVideoSurfaceView(surfaceView)
    }
}
