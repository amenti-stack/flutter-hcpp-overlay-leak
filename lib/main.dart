// Minimal reproduction for a GPU memory growth with hybrid composition++:
// a SurfaceView platform view, one ExoPlayer, and a new media item every
// 6 seconds. Two phases of 100 changes each, to tell two triggers apart:
//
//   A  on each change, a full-screen translucent scrim with a spinning
//      progress indicator above the platform view for 2 s (as a "loading"
//      overlay would be);
//   B  on each change, the platform view is resized (alternating between the
//      full screen and a letterboxed 16:9-in-4:3 frame), with no overlay.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

const _perPhase = 40;
const _every = Duration(seconds: 6);

/// Public test media of different sizes, so each change reconfigures the
/// decoder.
const _media = [
  'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
  'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final hcpp = await HybridAndroidViewController.checkIfSupported();
  debugPrint('REPRO hcpp supported: $hcpp');
  runApp(MaterialApp(home: ReproScreen(hcpp: hcpp)));
}

class ReproScreen extends StatefulWidget {
  const ReproScreen({required this.hcpp, super.key});

  final bool hcpp;

  @override
  State<ReproScreen> createState() => _ReproScreenState();
}

class _ReproScreenState extends State<ReproScreen> {
  static const _player = MethodChannel('repro/player');
  Timer? _timer;
  int _count = 0;
  bool _scrim = false;
  bool _letterbox = false;

  String get _phase => _count <= _perPhase ? 'A' : 'B';

  @override
  void initState() {
    super.initState();
    unawaited(_change());
    _timer = Timer.periodic(_every, (_) => _change());
  }

  Future<void> _change() async {
    if (_count >= 2 * _perPhase) {
      _timer?.cancel();
      debugPrint('REPRO done');
      return;
    }
    _count++;
    final url = _media[_count % _media.length];
    debugPrint(
      'REPRO change $_count phase $_phase '
      '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
    );
    await _player.invokeMethod<void>('play', {'url': url});
    if (_phase == 'A') {
      setState(() => _scrim = true);
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _scrim = false);
      });
    } else {
      setState(() => _letterbox = !_letterbox);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = PlatformViewLink(
      viewType: 'repro/video',
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      ),
      onCreatePlatformView: (params) {
        final controller = widget.hcpp
            ? PlatformViewsService.initHybridAndroidView(
                id: params.id,
                viewType: 'repro/video',
                layoutDirection: TextDirection.ltr,
                creationParamsCodec: const StandardMessageCodec(),
              )
            : PlatformViewsService.initExpensiveAndroidView(
                id: params.id,
                viewType: 'repro/video',
                layoutDirection: TextDirection.ltr,
                creationParamsCodec: const StandardMessageCodec(),
              );
        controller
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
        return controller;
      },
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Phase B: the same platform view, laid out at another size.
          Center(
            child: _letterbox
                ? AspectRatio(aspectRatio: 4 / 3, child: video)
                : SizedBox.expand(child: video),
          ),
          if (_scrim)
            const ColoredBox(
              color: Color(0x99000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Phase $_phase · change $_count of ${2 * _perPhase}',
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
