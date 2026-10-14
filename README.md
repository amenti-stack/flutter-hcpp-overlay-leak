# HCPP overlay GPU memory leak: minimal reproduction

A one-screen Flutter app that shows GPU memory growing, and never released, each time a full-screen
overlay with an animation is shown and removed above a `SurfaceView` platform view under hybrid
composition++ (`io.flutter.embedding.android.EnableHcpp=true`).

## What it does

- `android/app/src/main/kotlin/.../MainActivity.kt`: one Media3 ExoPlayer rendering into a `SurfaceView`
  inside a platform view, and a method channel to load a new media item. The player and the surface are
  never recreated.
- `lib/main.dart`: the platform view full screen, created with `PlatformViewsService.initHybridAndroidView`
  when `HybridAndroidViewController.checkIfSupported()` is true. Every 6 s it loads the next public test
  video. Two phases of 40 changes:
  - **A:** on each change, a full-screen `ColoredBox(Color(0x99000000))` with a centred
    `CircularProgressIndicator` is shown above the platform view for 2 s.
  - **B:** on each change, the platform view is resized (full screen ↔ 4:3), with no overlay.
- `tools/gpu-mem-sampler.sh`: samples the Mali kbase driver's per-process GPU memory every 10 s (root).

## Result

Xiaomi Mi TV box (Android 14, Amlogic, Mali-G310), Flutter 3.47.0, Impeller (Vulkan), HCPP active:

| | GPU memory |
|---|---|
| start | 32 MB |
| after phase A (40 overlay show/hide cycles) | 44 MB, in 4 MB steps |
| after phase B (40 resizes, no overlay) | 44 MB |
| idle afterwards | 44 MB, never released |

An earlier run with only a small text banner (no full-screen layer, no animation) for 300 changes stayed
flat (28 → 32 MB).

## Run

```sh
flutter build apk --profile
adb install -r build/app/outputs/flutter-apk/app-profile.apk
adb push tools/gpu-mem-sampler.sh /data/local/tmp/
adb shell "su -c 'nohup sh /data/local/tmp/gpu-mem-sampler.sh 60 10 >/dev/null 2>&1 &'"
adb shell am start -n dev.repro.hcpp_leak/.MainActivity
# about 9 minutes; the app logs "REPRO done"
adb shell su -c cat /data/local/tmp/gpu-mem.txt
```

Needs an API 34+ device with Vulkan for HCPP to be active (the app logs `REPRO hcpp supported: true`).
