import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../services/permission_service.dart';
import '../../services/face_recognition_service.dart';
import '../../repositories/face_repository.dart';
import '../../models/face_embedding_model.dart';

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

enum FaceDirection { center, left, right, up, down }

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _cameraController;
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final FaceRepository _repository = FaceRepository();

  CameraImage? _lastCameraImage;

  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _isDetecting = false;
  DateTime? _lastProcessingTime;
  String _statusMessage = 'Initializing camera...';
  String _instruction = '';

  // Directions management
  final List<FaceDirection> _requiredDirections = [
    FaceDirection.center,
    FaceDirection.left,
    FaceDirection.right,
    FaceDirection.up,
    FaceDirection.down
  ];
  int _currentStepIndex = 0;
  FaceDirection get _currentRequiredDirection =>
      _requiredDirections[_currentStepIndex];

  // Storage for embeddings
  final List<FaceEmbedding> _collectedEmbeddings = [];
  bool _permissionDenied = false;

  // Face positioning state
  bool _faceInPosition = false;
  Timer? _captureTimer;
  int _holdCountdown = 0;
  final int _holdDuration = 1; // Faster capture (1s)

  // Animation controller for the ring
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _permissionDenied) {
      _retryAfterSettings();
    } else if (state == AppLifecycleState.inactive) {
      _stopImageStream();
    } else if (state == AppLifecycleState.resumed &&
        _cameraController != null) {
      _startImageStream();
    }
  }

  Future<void> _retryAfterSettings() async {
    final hasPermission = await PermissionService.isCameraPermissionGranted();
    if (hasPermission) {
      setState(() {
        _permissionDenied = false;
        _isInitializing = true;
        _statusMessage = 'Initializing camera...';
      });
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final hasPermission = await PermissionService.requestCameraPermission();
      if (!hasPermission) {
        setState(() {
          _statusMessage = 'Camera permission denied';
          _isInitializing = false;
          _permissionDenied = true;
        });
        if (mounted) _showPermissionDeniedDialog();
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _statusMessage = 'No camera found';
          _isInitializing = false;
        });
        return;
      }

      // Find front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      setState(() {
        _isInitializing = false;
        _updateInstruction();
      });

      _startImageStream();
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to initialize camera: $e';
        _isInitializing = false;
      });
    }
  }

  void _startImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;
    if (_cameraController!.value.isStreamingImages) return;

    try {
      _cameraController!.startImageStream((CameraImage image) {
        if (!_isDetecting && !_isProcessing && mounted) {
          _isDetecting = true;
          _processImage(image);
        }
      });
      debugPrint('✅ [CAMERA] Image stream started');
    } catch (e) {
      debugPrint('❌ [CAMERA] Failed to start image stream: $e');
    }
  }

  void _stopImageStream() {
    _captureTimer?.cancel();
    if (_cameraController != null &&
        _cameraController!.value.isInitialized &&
        _cameraController!.value.isStreamingImages) {
      try {
        _cameraController!.stopImageStream();
      } catch (e) {
        debugPrint('❌ [CAMERA] Failed to stop image stream: $e');
      }
    }
  }

  Future<void> _processImage(CameraImage image) async {
    _lastCameraImage = image;

    // Throttle: Process every 200ms for smoother UI updates
    if (_lastProcessingTime != null &&
        DateTime.now().difference(_lastProcessingTime!).inMilliseconds < 200) {
      _isDetecting = false;
      return;
    }
    _lastProcessingTime = DateTime.now();

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final faces = await _faceService.detectFaces(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        _cancelHoldTimer();
        setState(() {
          _faceInPosition = false;
          _statusMessage = 'Keep your face in the circle';
        });
      } else if (faces.length > 1) {
        _cancelHoldTimer();
        setState(() {
          _faceInPosition = false;
          _statusMessage = 'Only one person allowed';
        });
      } else {
        _checkFacePosition(faces.first);
      }
    } catch (e) {
      // Ignore
    } finally {
      _isDetecting = false;
    }
  }

  void _checkFacePosition(Face face) {
    final headY = face.headEulerAngleY ?? 0; // Yaw (Left/Right)
    final headX = face.headEulerAngleX ?? 0; // Pitch (Up/Down)

    bool isInCorrectPosition = false;
    String feedback = '';

    // Thresholds
    const double angleThreshold = 12.0;

    switch (_currentRequiredDirection) {
      case FaceDirection.center:
        // Center: Look straight (close to 0 on both axes)
        isInCorrectPosition = headY.abs() < 10 && headX.abs() < 10;
        if (!isInCorrectPosition) {
          feedback = 'Look straight ahead';
        }
        break;

      case FaceDirection.left:
        // Left: Turn head LEFT (Head rotates Right relative to body, so Y is likely positive or negative depending on Lib)
        // MLKit: Left Head Turn => Positive Y (usually > 0)
        // Checking existing logic: Left was > 15
        isInCorrectPosition = headY > angleThreshold;
        if (!isInCorrectPosition) feedback = 'Turn head LEFT';
        break;

      case FaceDirection.right:
        // Right: Turn head RIGHT => Negative Y
        isInCorrectPosition = headY < -angleThreshold;
        if (!isInCorrectPosition) feedback = 'Turn head RIGHT';
        break;

      case FaceDirection.up:
        // Up: Look UP => Positive X (usually)
        isInCorrectPosition = headX > angleThreshold;
        if (!isInCorrectPosition) feedback = 'Look UP';
        break;

      case FaceDirection.down:
        // Down: Look DOWN => Negative X
        isInCorrectPosition = headX < -angleThreshold;
        if (!isInCorrectPosition) feedback = 'Look DOWN';
        break;
    }

    setState(() {
      _faceInPosition = isInCorrectPosition;
      if (isInCorrectPosition) {
        _statusMessage = 'Perfect! Hold still...';
      } else {
        _statusMessage = feedback;
      }
    });

    if (isInCorrectPosition) {
      _startHoldTimer(face);
    } else {
      _cancelHoldTimer();
    }
  }

  void _startHoldTimer(Face face) {
    if (_captureTimer != null) return;

    _holdCountdown = _holdDuration;
    _captureTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Just one tick for fast feel like FaceID
      _captureTimer?.cancel();
      _captureTimer = null;
      _captureFace(face);
    });
  }

  void _cancelHoldTimer() {
    _captureTimer?.cancel();
    _captureTimer = null;
  }

  Future<void> _captureFace(Face face) async {
    if (_isProcessing) return;
    if (_lastCameraImage == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Capturing...';
    });

    try {
      _stopImageStream();

      // Extract embedding
      final embeddings =
          await _faceService.extractEmbeddings(_lastCameraImage!, face);

      if (embeddings.isNotEmpty) {
        // Save to collection
        _collectedEmbeddings.add(
            FaceEmbedding(embedding: embeddings, timestamp: DateTime.now()));

        // Haptic feedback could go here

        // Next step
        if (_currentStepIndex < _requiredDirections.length - 1) {
          _currentStepIndex++;
          _updateInstruction();

          setState(() {
            _isProcessing = false;
            _faceInPosition = false;
          });

          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) _startImageStream();
        } else {
          // Finished!
          await _saveAllEmbeddings();
        }
      } else {
        // Failed extraction, retry
        setState(() => _isProcessing = false);
        if (mounted) _startImageStream();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isProcessing = false;
      });
      if (mounted) _startImageStream();
    }
  }

  void _updateInstruction() {
    switch (_currentRequiredDirection) {
      case FaceDirection.center:
        _instruction = 'Position your face in the circle';
        break;
      case FaceDirection.left:
        _instruction = 'Turn your head LEFT';
        break;
      case FaceDirection.right:
        _instruction = 'Turn your head RIGHT';
        break;
      case FaceDirection.up:
        _instruction = 'Tilt your head UP';
        break;
      case FaceDirection.down:
        _instruction = 'Tilt your head DOWN';
        break;
    }
    _statusMessage = _instruction;
  }

  Future<void> _saveAllEmbeddings() async {
    setState(() => _statusMessage = 'Saving face ID...');

    try {
      final userId = _repository.getCurrentUserId();
      if (userId == null) throw Exception('User not logged in');

      await _repository.saveFaceEmbeddings(userId, _collectedEmbeddings);
      await _repository.logFaceScan(
          userId: userId, scanType: 'registration', success: true);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) _showErrorDialog(e.toString());
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized)
        return null;
      if (image.planes.isEmpty) return null;

      final camera = _cameraController!.description;
      final rotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
              InputImageRotation.rotation0deg;
      final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;
      final plane = image.planes.first;

      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  // --- Dialogs ---

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 60, color: Colors.green),
            const SizedBox(height: 24),
            const Text('Face ID Set Up!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w300)),
            const SizedBox(height: 12),
            const Text('Your face has been securely registered.',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, foregroundColor: Colors.black),
              child: const Text('Done'),
            ),
          )
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentStepIndex = 0;
                _collectedEmbeddings.clear();
                _updateInstruction();
              });
              _startImageStream();
            },
            child: const Text('Try Again'),
          )
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Camera Permission',
            style: TextStyle(color: Colors.white)),
        content: const Text('Please enable camera access in settings.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => PermissionService.openSettings(),
              child: const Text('Settings')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _captureTimer?.cancel();
    _stopImageStream();
    _cameraController?.dispose();
    _faceService.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isInitializing
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : _cameraController == null ||
                    !_cameraController!.value.isInitialized
                ? const Center(
                    child: Text('Camera Error',
                        style: TextStyle(color: Colors.white)))
                : Stack(
                    children: [
                      // Camera Preview (Circular Mask)
                      Center(
                        child: ClipOval(
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.85,
                            height: MediaQuery.of(context).size.width * 0.85,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _cameraController!
                                    .value.previewSize!.height,
                                height:
                                    _cameraController!.value.previewSize!.width,
                                child: CameraPreview(_cameraController!),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // FaceID Ring Painter
                      Center(
                        child: CustomPaint(
                          size: Size(
                            MediaQuery.of(context).size.width * 0.95,
                            MediaQuery.of(context).size.width * 0.95,
                          ),
                          painter: FaceIDRingPainter(
                            completedSteps: _currentStepIndex,
                            totalSteps: _requiredDirections.length,
                            currentDirection: _currentRequiredDirection,
                            isInPosition: _faceInPosition,
                            pulseValue: _pulseController.value,
                          ),
                        ),
                      ),

                      // Instructions (Top)
                      Positioned(
                        top: 40,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            Text(
                              _instruction,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _statusMessage == _instruction
                                  ? ''
                                  : _statusMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _faceInPosition
                                    ? Colors.greenAccent
                                    : Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Cancel button (Bottom)
                      Positioned(
                        bottom: 40,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel',
                                style: TextStyle(color: Colors.white54)),
                          ),
                        ),
                      ),

                      // Progress Indicator (Bottom)
                      Positioned(
                        bottom: 80,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_requiredDirections.length,
                              (index) {
                            bool isActive = index == _currentStepIndex;
                            bool isDone = index < _currentStepIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isActive ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isDone
                                    ? Colors.green
                                    : (isActive
                                        ? Colors.white
                                        : Colors.white24),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                      )
                    ],
                  ),
      ),
    );
  }
}

// --- FaceID Style Ring Painter ---
class FaceIDRingPainter extends CustomPainter {
  final int completedSteps;
  final int totalSteps;
  final FaceDirection currentDirection;
  final bool isInPosition;
  final double pulseValue;

  FaceIDRingPainter({
    required this.completedSteps,
    required this.totalSteps,
    required this.currentDirection,
    required this.isInPosition,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    // Tick parameters
    final int tickCount = 60;
    final double tickLength = 15.0;
    final double tickWidth = 3.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = tickWidth;

    // Define segments for our directions
    // Map directions to rough clock positions
    // Center: 0 (All dimmed initially) -> Actually Center is usually Step 0.
    // Let's divide the circle into segments based on totalSteps.
    // However, FaceID fills up circularly.

    // Logic: We have 'totalSteps' milestones. We fill up the circle proportionally.
    // e.g. 5 steps. Step 0 done -> 0% fill? Or 20%?
    // Let's say we fill segments as we complete them.

    // However, to mimic the "Directional" feel:
    // When asking for "Left", we could highlight the Left side ticks?
    // User wants "Rotate to make it success".

    // Let's stick to the "Progress Fill" style which is cleaner.
    // Ticks are grey initially.
    // As steps complete, ticks turn Green.

    int ticksToFill = ((completedSteps / totalSteps) * tickCount).round();

    // Draw Ticks
    for (int i = 0; i < tickCount; i++) {
      final angle =
          (i * 2 * math.pi / tickCount) - (math.pi / 2); // Start from top
      final isFilled = i < ticksToFill;

      // Active "Cursor" feel if in position
      bool isPulse = false;
      if (isInPosition && i >= ticksToFill && i < ticksToFill + 5) {
        isPulse = true;
      }

      final startOffset = Offset(
        center.dx + (radius - tickLength) * math.cos(angle),
        center.dy + (radius - tickLength) * math.sin(angle),
      );

      final endOffset = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      if (isFilled) {
        paint.color = Colors.green;
      } else if (isPulse) {
        paint.color = Color.lerp(Colors.white, Colors.greenAccent, pulseValue)!;
      } else {
        paint.color = Colors.white24;
      }

      canvas.drawLine(startOffset, endOffset, paint);
    }
  }

  @override
  bool shouldRepaint(FaceIDRingPainter oldDelegate) => true;
}
