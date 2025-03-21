package com.example.soccertimeapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.view.WindowManager
import android.app.ActivityManager
import android.content.Context
import android.view.SurfaceView

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.soccertimeapp/settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "disableHardwareAcceleration") {
                try {
                    // Clear hardware acceleration flags
                    window.clearFlags(WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED)
                    
                    // Add hook to trap OpenGL errors in SurfaceView
                    val decorView = window.decorView
                    val surfaceViews = findSurfaceViews(decorView)
                    for (view in surfaceViews) {
                        // Set software rendering for SurfaceView
                        view.setZOrderOnTop(false)
                    }
                    
                    result.success(true)
                } catch (e: Exception) {
                    result.error("OPENGL_ERROR", "Failed to disable hardware acceleration", e.message)
                }
            } else {
                result.notImplemented()
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        try {
            // Check for OpenGL capability and set process priority
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val configurationInfo = activityManager.deviceConfigurationInfo
            
            if (configurationInfo.reqGlEsVersion < 0x20000) {
                // Device doesn't support OpenGL ES 2.0+, lower rendering quality
                window.setFlags(
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED.inv(),
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
                )
            }
            
            // Set process to background priority to reduce OpenGL pressure
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_BACKGROUND)
        } catch (e: Exception) {
            println("Error configuring OpenGL: ${e.message}")
        }
        
        super.onCreate(savedInstanceState)
    }

    // Helper function to find all SurfaceView instances in the view hierarchy
    private fun findSurfaceViews(view: android.view.View): List<SurfaceView> {
        val surfaceViews = mutableListOf<SurfaceView>()
        
        if (view is SurfaceView) {
            surfaceViews.add(view)
        } else if (view is android.view.ViewGroup) {
            for (i in 0 until view.childCount) {
                surfaceViews.addAll(findSurfaceViews(view.getChildAt(i)))
            }
        }
        
        return surfaceViews
    }
}
