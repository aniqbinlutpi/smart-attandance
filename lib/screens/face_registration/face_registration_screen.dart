import 'dart:async';
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

enum FaceDirection { center, left, right }

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final FaceRepository _repository = FaceRepository();
  // Removed redundant local FaceDetector to save resources

  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _isDetecting = false;
  DateTime? _lastProcessingTime; // For throttling
  String _statusMessage = 'Initializing camera...';
  String _instruction = '';
  int _captureCount = 0;
  final int _requiredCaptures = 3;
  final List<List<double>> _capturedEmbeddings = [];
  bool _permissionDenied = false;

  // Current pose tracking
  FaceDirection _currentRequiredDirection = FaceDirection.center;
  bool _faceInPosition = false;
  Timer? _captureTimer;
  int _holdCountdown = 0;
  final int _holdDuration = 2; // seconds to hold position

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
        if (mounted) {
          _showPermissionDeniedDialog();
        }
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
        _instruction = _getInstructionForDirection(_currentRequiredDirection);
        _statusMessage = 'Position your face in the oval';
      });

      // Start real-time face detection
      _startImageStream();
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to initialize camera: $e';
        _isInitializing = false;
      });
    }
  }

  void _startImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      debugPrint('⚠️ [CAMERA] Cannot start stream - controller not ready');
      return;
    }

    // Check if already streaming
    if (_cameraController!.value.isStreamingImages) {
      debugPrint('⚠️ [CAMERA] Already streaming images');
      return;
    }

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
        debugPrint('✅ [CAMERA] Image stream stopped');
      } catch (e) {
        debugPrint('❌ [CAMERA] Failed to stop image stream: $e');
      }
    }
  }

  Future<void> _processImage(CameraImage image) async {
    // Throttle processing to prevent crash/overheating (process every 400ms)
    // This significantly reduces resource usage and connection drops
    if (_lastProcessingTime != null &&
        DateTime.now().difference(_lastProcessingTime!).inMilliseconds < 400) {
      _isDetecting = false;
      return;
    }
    _lastProcessingTime = DateTime.now();

    try {
      // Check brightness first
      final brightness = _calculateBrightness(image);
      // Increased threshold to 90 to ensure better quality (prev. 50 was too low)
      if (brightness < 90) {
        if (mounted) {
          _cancelHoldTimer();
          setState(() {
            _statusMessage = 'Too dark. Please find better lighting.';
            _faceInPosition = false;
          });
        }
        _isDetecting = false;
        return;
      }

      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      // Use shared service detector instead of a redundant local one
      final faces = await _faceService.detectFaces(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        _cancelHoldTimer();
        setState(() {
          _faceInPosition = false;
          _statusMessage = 'No face detected';
          _instruction = 'Position your face in the oval';
        });
      } else if (faces.length > 1) {
        _cancelHoldTimer();
        setState(() {
          _faceInPosition = false;
          _statusMessage = 'Multiple faces detected';
          _instruction = 'Only one person should be in frame';
        });
      } else {
        final face = faces.first;
        _checkFacePosition(face);
      }
    } catch (e) {
      // Silent fail for streaming
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      // Additional null safety checks
      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        return null;
      }

      if (image.planes.isEmpty) {
        return null;
      }

      final camera = _cameraController!.description;
      final rotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation);
      if (rotation == null) return null;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      final plane = image.planes.first;
      if (plane.bytes.isEmpty) return null;

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
      debugPrint('⚠️ [CAMERA] Error converting image: $e');
      return null;
    }
  }

  double _calculateBrightness(CameraImage image) {
    try {
      if (image.planes.isEmpty) return 255.0;
      final plane = image.planes.first; // Y plane (Luminance)
      final bytes = plane.bytes;
      if (bytes.isEmpty) return 255.0;

      int total = 0;
      int count = 0;
      const int stride = 20;
      for (int i = 0; i < bytes.length; i += stride) {
        total += bytes[i];
        count++;
      }

      if (count == 0) return 0.0;
      return total / count;
    } catch (e) {
      return 255.0;
    }
  }

  void _checkFacePosition(Face face) {
    final headY = face.headEulerAngleY ?? 0;
    bool isInCorrectPosition = false;
    String feedback = '';

    switch (_currentRequiredDirection) {
      case FaceDirection.center:
        isInCorrectPosition = headY.abs() < 10;
        if (!isInCorrectPosition) {
          feedback = headY > 0
              ? 'Turn your head slightly right'
              : 'Turn your head slightly left';
        }
        break;
      case FaceDirection.left:
        isInCorrectPosition = headY > 15 && headY < 40;
        if (headY <= 15) {
          feedback = 'Turn your head more to the left';
        } else if (headY >= 40) {
          feedback = 'Turn back slightly';
        }
        break;
      case FaceDirection.right:
        isInCorrectPosition = headY < -15 && headY > -40;
        if (headY >= -15) {
          feedback = 'Turn your head more to the right';
        } else if (headY <= -40) {
          feedback = 'Turn back slightly';
        }
        break;
    }

    // Check face quality
    final quality = _faceService.validateFaceQuality(face);
    if (!quality['valid']) {
      isInCorrectPosition = false;
      feedback = quality['message'];
    }

    setState(() {
      _faceInPosition = isInCorrectPosition;
      if (isInCorrectPosition) {
        _statusMessage = 'Hold still...';
        _instruction = _getInstructionForDirection(_currentRequiredDirection);
      } else {
        _statusMessage = feedback;
        _instruction = _getInstructionForDirection(_currentRequiredDirection);
      }
    });

    if (isInCorrectPosition) {
      _startHoldTimer(face);
    } else {
      _cancelHoldTimer();
    }
  }

  void _startHoldTimer(Face face) {
    if (_captureTimer != null) return; // Already counting

    _holdCountdown = _holdDuration;
    _captureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _holdCountdown--;
      });

      if (_holdCountdown <= 0) {
        timer.cancel();
        _captureTimer = null;
        _captureFace(face);
      }
    });
  }

  void _cancelHoldTimer() {
    _captureTimer?.cancel();
    _captureTimer = null;
    if (mounted) {
      setState(() {
        _holdCountdown = 0;
      });
    }
  }

  Future<void> _captureFace(Face face) async {
    if (_isProcessing) return;

    debugPrint(
        '🎯 [CAPTURE] Starting capture for direction: $_currentRequiredDirection');
    debugPrint(
        '🎯 [CAPTURE] Current capture count: $_captureCount / $_requiredCaptures');

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Capturing...';
    });

    try {
      // Stop stream temporarily to avoid conflicts
      _stopImageStream();
      debugPrint('🎯 [CAPTURE] Image stream stopped');

      // Use the face data from the live stream directly
      // No need to take a picture and re-detect - we already have the face!
      debugPrint(
          '🎯 [CAPTURE] Using face from live stream for embedding extraction');
      debugPrint('🎯 [CAPTURE] Face bounding box: ${face.boundingBox}');
      debugPrint('🎯 [CAPTURE] Face landmarks count: ${face.landmarks.length}');
      debugPrint('🎯 [CAPTURE] Face contours count: ${face.contours.length}');

      // Extract embeddings from the current face
      debugPrint('🎯 [CAPTURE] Extracting embeddings...');
      final embeddings = _faceService.extractEmbeddings(face);
      debugPrint(
          '🎯 [CAPTURE] Embeddings extracted: ${embeddings.length} features');

      if (embeddings.isEmpty) {
        debugPrint('❌ [CAPTURE] Empty embeddings extracted');
        setState(() {
          _statusMessage = 'Failed to extract face features, try again';
          _isProcessing = false;
        });
        // Delay before restarting stream to avoid iOS camera bug
        await Future.delayed(const Duration(milliseconds: 300));
        _startImageStream();
        return;
      }

      _capturedEmbeddings.add(embeddings);
      _captureCount++;
      debugPrint(
          '✅ [CAPTURE] Capture successful! Count: $_captureCount / $_requiredCaptures');

      if (_captureCount < _requiredCaptures) {
        // Move to next direction
        debugPrint('🎯 [CAPTURE] Moving to next direction...');
        _moveToNextDirection();
        setState(() {
          _isProcessing = false;
        });
        // Delay before restarting stream to avoid iOS camera bug
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          _startImageStream();
        }
      } else {
        // All captures done
        debugPrint('🎯 [CAPTURE] All captures done, saving embeddings...');
        await _saveFaceEmbeddings();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [CAPTURE] Error: $e');
      debugPrint('❌ [CAPTURE] Stack trace: $stackTrace');
      setState(() {
        _statusMessage = 'Capture error: ${e.toString()}';
        _isProcessing = false;
      });
      // Delay before restarting stream to avoid iOS camera bug
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        _startImageStream();
      }
    }
  }

  void _moveToNextDirection() {
    switch (_currentRequiredDirection) {
      case FaceDirection.center:
        _currentRequiredDirection = FaceDirection.left;
        break;
      case FaceDirection.left:
        _currentRequiredDirection = FaceDirection.right;
        break;
      case FaceDirection.right:
        // Done
        break;
    }

    setState(() {
      _instruction = _getInstructionForDirection(_currentRequiredDirection);
      _statusMessage = 'Great! Now ${_instruction.toLowerCase()}';
      _faceInPosition = false;
    });
  }

  String _getInstructionForDirection(FaceDirection direction) {
    switch (direction) {
      case FaceDirection.center:
        return 'Look straight ahead';
      case FaceDirection.left:
        return 'Turn your head to the LEFT';
      case FaceDirection.right:
        return 'Turn your head to the RIGHT';
    }
  }

  Future<void> _saveFaceEmbeddings() async {
    debugPrint('💾 [SAVE] Starting save process...');
    debugPrint(
        '💾 [SAVE] Total embeddings to average: ${_capturedEmbeddings.length}');

    setState(() {
      _statusMessage = 'Saving your face data...';
    });

    try {
      debugPrint('💾 [SAVE] Averaging embeddings...');
      final averagedEmbedding =
          _faceService.averageEmbeddings(_capturedEmbeddings);
      debugPrint(
          '💾 [SAVE] Averaged embedding size: ${averagedEmbedding.length}');

      final faceEmbedding = FaceEmbedding(
        embedding: averagedEmbedding,
        timestamp: DateTime.now(),
      );

      final userId = _repository.getCurrentUserId();
      debugPrint('💾 [SAVE] User ID: $userId');

      if (userId == null) {
        throw Exception('User not logged in');
      }

      debugPrint('💾 [SAVE] Calling saveFaceEmbeddings...');
      await _repository.saveFaceEmbeddings(userId, [faceEmbedding]);
      debugPrint('✅ [SAVE] Face embeddings saved successfully!');

      debugPrint('💾 [SAVE] Logging face scan...');
      await _repository.logFaceScan(
        userId: userId,
        scanType: 'registration',
        success: true,
      );
      debugPrint('✅ [SAVE] Face scan logged successfully!');

      if (mounted) {
        debugPrint('✅ [SAVE] Showing success dialog...');
        _showSuccessDialog();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [SAVE] Error saving: $e');
      debugPrint('❌ [SAVE] Stack trace: $stackTrace');
      setState(() {
        _statusMessage = 'Save failed: ${e.toString()}';
        _isProcessing = false;
      });
      // Show error dialog for better UX
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white24, width: 1),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withValues(alpha: 0.2),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 60,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Face Registered!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w300,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your face has been successfully registered for attendance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, true); // Go back with success
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white24, width: 1),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.2),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Registration Failed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w300,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                // Reset and try again
                setState(() {
                  _captureCount = 0;
                  _capturedEmbeddings.clear();
                  _currentRequiredDirection = FaceDirection.center;
                  _instruction =
                      _getInstructionForDirection(_currentRequiredDirection);
                  _isProcessing = false;
                });
                _startImageStream();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white24, width: 1),
        ),
        title: const Row(
          children: [
            Icon(Icons.camera_alt_outlined, color: Colors.white70),
            SizedBox(width: 12),
            Text(
              'Camera Permission Required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        content: const Text(
          'This app needs camera access for face registration. Please enable camera permission in Settings.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await PermissionService.openSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Open Settings',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
          ),
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
    // Detector closed via service
    _faceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Register Face',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isInitializing
          ? _buildLoadingView()
          : _cameraController == null || !_cameraController!.value.isInitialized
              ? _buildErrorView()
              : _buildCameraView(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _statusMessage,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.white38,
            ),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      children: [
        // Camera preview
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _cameraController!.value.previewSize!.height,
              height: _cameraController!.value.previewSize!.width,
              child: CameraPreview(_cameraController!),
            ),
          ),
        ),

        // Face oval overlay with animation
        CustomPaint(
          size: Size.infinite,
          painter: FaceOvalPainter(
            isInPosition: _faceInPosition,
            progress: _holdCountdown > 0
                ? (_holdDuration - _holdCountdown) / _holdDuration
                : 0,
          ),
        ),

        // Direction indicator
        Positioned(
          top: MediaQuery.of(context).size.height * 0.15,
          left: 0,
          right: 0,
          child: _buildDirectionIndicator(),
        ),

        // Top instruction overlay
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.9),
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              children: [
                // Progress dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _requiredCaptures,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index < _captureCount
                            ? Colors.green
                            : Colors.white.withValues(alpha: 0.3),
                        border: Border.all(
                          color: index < _captureCount
                              ? Colors.green
                              : Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: index < _captureCount
                          ? const Icon(Icons.check,
                              size: 8, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Instruction
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: _faceInPosition
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _faceInPosition
                          ? Colors.green.withValues(alpha: 0.5)
                          : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _instruction,
                    style: TextStyle(
                      color: _faceInPosition ? Colors.green : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom status
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child: Column(
            children: [
              if (_holdCountdown > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'Capturing in $_holdCountdown...',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDirectionIndicator() {
    IconData icon;
    String label;

    switch (_currentRequiredDirection) {
      case FaceDirection.center:
        icon = Icons.person;
        label = 'CENTER';
        break;
      case FaceDirection.left:
        icon = Icons.arrow_back;
        label = 'LEFT';
        break;
      case FaceDirection.right:
        icon = Icons.arrow_forward;
        label = 'RIGHT';
        break;
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _faceInPosition
                ? Colors.green.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
            border: Border.all(
              color: _faceInPosition ? Colors.green : Colors.white38,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            size: 32,
            color: _faceInPosition ? Colors.green : Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: _faceInPosition ? Colors.green : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

// Custom painter for face oval overlay with progress
class FaceOvalPainter extends CustomPainter {
  final bool isInPosition;
  final double progress;

  FaceOvalPainter({
    required this.isInPosition,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 30);
    final ovalWidth = size.width * 0.65;
    final ovalHeight = size.height * 0.38;

    // Draw semi-transparent overlay outside the oval
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(
          Rect.fromCenter(center: center, width: ovalWidth, height: ovalHeight))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );

    // Draw oval border
    final borderPaint = Paint()
      ..color =
          isInPosition ? Colors.green : Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isInPosition ? 4 : 3;

    canvas.drawOval(
      Rect.fromCenter(center: center, width: ovalWidth, height: ovalHeight),
      borderPaint,
    );

    // Draw progress arc when holding
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCenter(
            center: center, width: ovalWidth + 10, height: ovalHeight + 10),
        -1.5708, // Start from top (-90 degrees in radians)
        progress * 6.2832, // Full circle is 2*PI
        false,
        progressPaint,
      );
    }

    // Draw corner guides
    final guidePaint = Paint()
      ..color = isInPosition ? Colors.green : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final guideLength = 25.0;
    final rect =
        Rect.fromCenter(center: center, width: ovalWidth, height: ovalHeight);

    // Corner guides
    _drawCorner(canvas, rect.topLeft, guideLength, 1, 1, guidePaint);
    _drawCorner(canvas, rect.topRight, guideLength, -1, 1, guidePaint);
    _drawCorner(canvas, rect.bottomLeft, guideLength, 1, -1, guidePaint);
    _drawCorner(canvas, rect.bottomRight, guideLength, -1, -1, guidePaint);
  }

  void _drawCorner(Canvas canvas, Offset corner, double length, int xDir,
      int yDir, Paint paint) {
    canvas.drawLine(
        corner, Offset(corner.dx + length * xDir, corner.dy), paint);
    canvas.drawLine(
        corner, Offset(corner.dx, corner.dy + length * yDir), paint);
  }

  @override
  bool shouldRepaint(covariant FaceOvalPainter oldDelegate) =>
      isInPosition != oldDelegate.isInPosition ||
      progress != oldDelegate.progress;
}
