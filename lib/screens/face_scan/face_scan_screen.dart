import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../services/permission_service.dart';
import '../../services/location_service.dart';
import '../../services/face_recognition_service.dart';
import '../../repositories/face_repository.dart';

enum ScanStep { blink, verifying }

class FaceScanScreen extends StatefulWidget {
  final String scanType; // 'checkin' or 'checkout'

  const FaceScanScreen({
    super.key,
    required this.scanType,
  });

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final FaceRepository _repository = FaceRepository();
  // SSD removed: Redundant FaceDetector

  CameraImage? _lastCameraImage;

  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _isDetecting = false;
  String _statusMessage = 'Initializing...';
  bool _locationValid = false;
  bool _faceDetected = false;

  // Auto-scan
  Timer? _scanTimer;
  int _holdCountdown = 0;
  final int _holdDuration = 2; // seconds to hold for auto-scan

  // Stored embeddings
  List<List<double>>? _storedEmbeddings;

  // Retry logic
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive) {
      _stopImageStream();
    } else if (state == AppLifecycleState.resumed &&
        _cameraController != null &&
        !_isInitializing) {
      _startImageStream();
    }
  }

  Future<void> _initialize() async {
    try {
      // Step 1: Check location
      setState(() {
        _statusMessage = 'Checking location...';
        _scanStep = ScanStep.blink;
      });

      final locationResult = await LocationService.validateLocation();
      if (!locationResult['valid']) {
        setState(() {
          _statusMessage = locationResult['message'];
          _isInitializing = false;
        });
        if (mounted) {
          _showErrorDialog(locationResult['message']);
        }
        return;
      }

      _locationValid = true;
      debugPrint('✅ [SCAN] Location verified');

      // Step 2: Check if face is registered
      setState(() => _statusMessage = 'Checking face registration...');

      final userId = _repository.getCurrentUserId();
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final isRegistered = await _repository.isFaceRegistered(userId);
      if (!isRegistered) {
        setState(() {
          _statusMessage = 'Please register your face first';
          _isInitializing = false;
        });
        if (mounted) {
          _showErrorDialog(
              'Please register your face first in Profile settings');
        }
        return;
      }
      debugPrint('✅ [SCAN] Face is registered');

      // Step 3: Load stored embeddings
      setState(() => _statusMessage = 'Loading face data...');
      final storedFaceData = await _repository.getFaceEmbeddings(userId);
      if (storedFaceData == null || storedFaceData.isEmpty) {
        throw Exception('No stored face data found');
      }
      _storedEmbeddings = storedFaceData.map((e) => e.embedding).toList();
      debugPrint(
          '✅ [SCAN] Loaded ${_storedEmbeddings!.length} stored embeddings');

      // Step 4: Check session status (check-in/check-out logic)
      if (widget.scanType == 'checkin') {
        setState(() => _statusMessage = 'Checking current session...');

        final hasActiveSession = await _repository.hasActiveCheckIn(userId);
        if (hasActiveSession) {
          setState(() {
            _statusMessage = 'You are currently checked in';
            _isInitializing = false;
          });
          if (mounted) {
            _showErrorDialog(
                'You have an active session. Please check out first.');
          }
          return;
        }
        debugPrint('✅ [SCAN] No active session, allowing check-in');
      } else {
        // For checkout, verify there's an active session
        final todayAttendance = await _repository.getTodayAttendance(userId);

        // If no record at all OR latest record is already checked out
        if (todayAttendance == null ||
            todayAttendance['check_out_time'] != null) {
          setState(() {
            _statusMessage = 'No active check-in found';
            _isInitializing = false;
          });
          if (mounted) {
            _showErrorDialog('You are not checked in. Please check in first.');
          }
          return;
        }
        debugPrint('✅ [SCAN] Found active session, allowing check-out');
      }

      // Step 5: Initialize camera
      await _initializeCamera();
    } catch (e) {
      debugPrint('❌ [SCAN] Initialization error: $e');
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
        _isInitializing = false;
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() => _statusMessage = 'Requesting camera permission...');

      final hasPermission = await PermissionService.requestCameraPermission();
      if (!hasPermission) {
        setState(() {
          _statusMessage = 'Camera permission denied';
          _isInitializing = false;
        });
        return;
      }

      setState(() => _statusMessage = 'Initializing camera...');

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
        ResolutionPreset.high, // High resolution for better face detail
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      setState(() {
        _isInitializing = false;
        _statusMessage = 'Position your face in the frame';
      });

      // Start real-time face detection
      _startImageStream();
    } catch (e) {
      debugPrint('❌ [SCAN] Camera init error: $e');
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
    _scanTimer?.cancel();
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

  DateTime _lastProcessTime = DateTime.now();

  Future<void> _processImage(CameraImage image) async {
    _lastCameraImage = image;
    // Throttle processing to prevent crash/overheating (process every 50ms to catch blinks)
    if (DateTime.now().difference(_lastProcessTime).inMilliseconds < 50) {
      _isDetecting = false; // CRITICAL FIX: Reset flag if throttled
      return;
    }
    _lastProcessTime = DateTime.now();

    try {
      // Brightness check removed to prevent false positives in dark rooms.
      // We rely solely on ML Kit's face detection capability.

      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final faces = await _faceService.detectFaces(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        _cancelScanTimer();
        setState(() {
          _faceDetected = false;
          _statusMessage = 'No face detected';
        });
      } else if (faces.length > 1) {
        _cancelScanTimer();
        setState(() {
          _faceDetected = false;
          _statusMessage = 'Multiple faces detected';
        });
      } else {
        final face = faces.first;

        // Check face quality
        // We disable 'checkEyes' here because we want to allow blinking for liveness check!
        final quality =
            _faceService.validateFaceQuality(face, checkEyes: false);

        // Debug Liveness
        if (quality['valid']) {
          debugPrint(
              '👁️ Eyes: L=${face.leftEyeOpenProbability?.toStringAsFixed(2)} R=${face.rightEyeOpenProbability?.toStringAsFixed(2)}');
        }

        if (!quality['valid']) {
          _cancelScanTimer();
          setState(() {
            _faceDetected = false;
            _statusMessage = quality['message'];
          });
        } else {
          // Face is good, start liveness check
          setState(() {
            _faceDetected = true;
          });
          _detectLiveness(face);
        }
      }
    } catch (e) {
      // Silent fail for streaming
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
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

      // For Android YUV420, we need to pass all planes
      if (defaultTargetPlatform == TargetPlatform.android) {
        return InputImage.fromBytes(
          bytes: _concatenatePlanes(image.planes),
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.nv21, // Explicitly set NV21 for Android
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );
      } else {
        // For iOS BGRA8888, use first plane
        final plane = image.planes.first;
        if (plane.bytes.isEmpty) return null;

        return InputImage.fromBytes(
          bytes: plane.bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.bgra8888, // Explicitly set BGRA8888 for iOS
            bytesPerRow: plane.bytesPerRow,
          ),
        );
      }
    } catch (e) {
      return null;
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  // Liveness state
  ScanStep _scanStep = ScanStep.blink;
  bool _eyesClosed = false;

  void _detectLiveness(Face face) {
    if (!_isDetecting) return;

    switch (_scanStep) {
      case ScanStep.blink:
        _checkLivenessAndVerify(face);
        break;
      case ScanStep.verifying:
        // If we are in verifying state but not processing (e.g. retrying),
        // we should attempt to scan the face again immediately.
        if (!_isProcessing) {
          _performFaceScan(face);
        }
        break;
    }
  }

  void _checkLivenessAndVerify(Face face) {
    final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;
    final smileProb = face.smilingProbability ?? 0.0;

    // Debug Liveness
    debugPrint(
        '😐 Liveness: Eyes(L=${leftEyeOpen.toStringAsFixed(2)}, R=${rightEyeOpen.toStringAsFixed(2)}) Smile=${smileProb.toStringAsFixed(2)}');

    // 1. Check for Smile (Easier alternative to blink)
    if (smileProb > 0.6) {
      setState(() {
        _scanStep = ScanStep.verifying;
        _statusMessage = 'Smile detected! Verifying...';
      });
      _performFaceScan(face);
      return;
    }

    // 2. Check for Blink
    // Relaxed threshold to 0.5 to make blinking easier
    final isLikelyClosed = leftEyeOpen < 0.5 && rightEyeOpen < 0.5;
    // Allow if EITHER eye opens back up (handles winking or uneven lighting)
    final isLikelyOpen = leftEyeOpen > 0.6 || rightEyeOpen > 0.6;

    if (isLikelyClosed) {
      _eyesClosed = true;
      debugPrint('😑 [LIVENESS] Eyes Closed detected!');
      if (mounted) {
        setState(() => _statusMessage = 'Keep blinking... (Eyes Closed)');
      }
    } else if (isLikelyOpen && _eyesClosed) {
      // Blink complete
      debugPrint('😳 [LIVENESS] Blink Loop Complete!');
      setState(() {
        _eyesClosed = false;
        _scanStep = ScanStep.verifying;
        _statusMessage = 'Blink detected! Verifying...';
      });
      _performFaceScan(face);
    } else {
      if (mounted) {
        if (_eyesClosed) {
          setState(() => _statusMessage = 'Open your eyes now');
        } else if (_statusMessage != 'Blink or Smile to verify...') {
          setState(() => _statusMessage = 'Blink or Smile to verify...');
        }
      }
    }
  }

  void _cancelScanTimer() {
    _scanTimer?.cancel();
    _scanTimer = null;
    if (mounted) {
      setState(() {
        _holdCountdown = 0;
      });
    }
  }

  Future<void> _performFaceScan(Face face) async {
    if (_isProcessing) return;
    if (_storedEmbeddings == null || _storedEmbeddings!.isEmpty) return;
    if (_lastCameraImage == null) return; // Safety check

    debugPrint('🔍 [SCAN] Starting face verification...');

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Verifying face...';
    });

    try {
      _stopImageStream();

      // Extract embeddings from the detected face
      debugPrint('🔍 [SCAN] Extracting embeddings from detected face...');
      // Pass the CAMERA IMAGE now
      final scannedEmbedding =
          await _faceService.extractEmbeddings(_lastCameraImage!, face);
      debugPrint('🔍 [SCAN] Extracted ${scannedEmbedding.length} features');

      if (scannedEmbedding.isEmpty) {
        setState(() {
          _statusMessage = 'Failed to extract face features';
          _isProcessing = false;
        });
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) _startImageStream();
        return;
      }

      // Compare with stored embeddings
      debugPrint('🔍 [SCAN] Comparing with stored embeddings...');
      final matchResult = _faceService.findBestMatch(
        scannedEmbedding,
        _storedEmbeddings!,
      );
      debugPrint(
          '🔍 [SCAN] Match result: ${matchResult['similarityPercent']}%');

      // Get current location for logging
      final position = await LocationService.getCurrentLocation();
      final userId = _repository.getCurrentUserId()!;

      // Log scan attempt
      final scanLogId = await _repository.logFaceScan(
        userId: userId,
        scanType: 'attendance',
        success: matchResult['match'],
        similarityScore: matchResult['similarity'],
        errorMessage: matchResult['match'] ? null : 'Face not recognized',
        locationLat: position.latitude,
        locationLng: position.longitude,
      );
      debugPrint('🔍 [SCAN] Scan logged: $scanLogId');

      if (matchResult['match']) {
        debugPrint('✅ [SCAN] Face recognized!');
        // Face recognized - record attendance
        _retryCount = 0; // Reset retry count
        await _recordAttendance(
          userId: userId,
          similarityScore: matchResult['similarity'],
          scanLogId: scanLogId,
          position: position,
        );
      } else {
        debugPrint('❌ [SCAN] Face not recognized. Retry: $_retryCount');

        // Retry logic
        if (_retryCount < 3) {
          _retryCount++;
          setState(() {
            _statusMessage = "Verifying... (Attempt ${_retryCount + 1})";
            _isProcessing = false;
          });

          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) _startImageStream();
        } else {
          // Failure after retries
          setState(() {
            _statusMessage = "Face mismatch. Please re-register in Profile.";
            _isProcessing = false;
            _retryCount = 0;
          });
          if (mounted) {
            _showErrorDialog(
                "Face not recognized.\n\nSince we improved security, please go to Profile > Face Registration and register again.");
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [SCAN] Error: $e');
      debugPrint('❌ [SCAN] Stack trace: $stackTrace');
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
        _isProcessing = false;
      });
      if (mounted) {
        _showErrorDialog('Failed to scan face: ${e.toString()}');
      }
    }
  }

  Future<void> _recordAttendance({
    required String userId,
    required double similarityScore,
    required String scanLogId,
    required position,
  }) async {
    try {
      setState(() => _statusMessage = 'Recording attendance...');
      debugPrint('📝 [SCAN] Recording attendance...');

      // Get user data
      final userData = await _repository.getCurrentUser();
      if (userData == null) {
        throw Exception('User data not found');
      }

      final userName = userData['name'] ?? 'Unknown';

      if (widget.scanType == 'checkin') {
        // Record check-in
        debugPrint('📝 [SCAN] Recording check-in...');
        await _repository.recordAttendanceWithFace(
          userId: userId,
          userName: userName,
          status: 'present',
          location: LocationService.formatLocation(position),
          faceSimilarityScore: similarityScore,
          faceScanLogId: scanLogId,
          locationLat: position.latitude,
          locationLng: position.longitude,
        );
        debugPrint('✅ [SCAN] Check-in recorded!');

        // Show success
        if (mounted) {
          _showSuccessDialog(
            'Check-In Successful!',
            'Face recognized with ${(similarityScore * 100).toStringAsFixed(1)}% match',
          );
        }
      } else {
        // Record check-out
        debugPrint('📝 [SCAN] Recording check-out...');
        final todayAttendance = await _repository.getTodayAttendance(userId);
        if (todayAttendance != null) {
          await _repository.checkOut(todayAttendance['id']);
          debugPrint('✅ [SCAN] Check-out recorded!');

          if (mounted) {
            _showSuccessDialog(
              'Check-Out Successful!',
              'Face recognized with ${(similarityScore * 100).toStringAsFixed(1)}% match',
            );
          }
        } else {
          throw Exception('No check-in record found for today');
        }
      }
    } catch (e) {
      debugPrint('❌ [SCAN] Failed to record attendance: $e');
      setState(() {
        _statusMessage = 'Failed to record attendance: ${e.toString()}';
        _isProcessing = false;
      });
      if (mounted) {
        _showErrorDialog('Failed to record attendance: ${e.toString()}');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
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
              'Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w300,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
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
                Navigator.pop(context); // Close scan screen
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
                'OK',
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

  void _showSuccessDialog(String title, String message) {
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
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w300,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
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
                Navigator.pop(context, true); // Close scan screen with success
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanTimer?.cancel();
    _stopImageStream();
    _cameraController?.dispose();
    _faceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCheckIn = widget.scanType == 'checkin';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          isCheckIn ? 'Check In' : 'Check Out',
          style: const TextStyle(
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
              : _buildCameraView(isCheckIn),
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
            textAlign: TextAlign.center,
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

  Widget _buildCameraView(bool isCheckIn) {
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

        // Face oval overlay
        CustomPaint(
          size: Size.infinite,
          painter: FaceScanOvalPainter(
            isDetected: _faceDetected,
            progress: _holdCountdown > 0
                ? (_holdDuration - _holdCountdown) / _holdDuration
                : 0,
          ),
        ),

        // Top overlay with status
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
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _faceDetected
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                    border: Border.all(
                      color: _faceDetected ? Colors.green : Colors.white24,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isCheckIn ? Icons.login : Icons.logout,
                    color: _faceDetected ? Colors.green : Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isCheckIn ? 'CHECK IN' : 'CHECK OUT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _faceDetected
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _faceDetected
                          ? Colors.green.withValues(alpha: 0.5)
                          : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _faceDetected ? Colors.green : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (_locationValid)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Location verified',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
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
                    'Verifying in $_holdCountdown...',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else if (_isProcessing)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Processing...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// Custom painter for face scan overlay with progress
class FaceScanOvalPainter extends CustomPainter {
  final bool isDetected;
  final double progress;

  FaceScanOvalPainter({
    required this.isDetected,
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
      ..color = isDetected ? Colors.green : Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDetected ? 4 : 3;

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
      ..color = isDetected ? Colors.green : Colors.white
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
  bool shouldRepaint(covariant FaceScanOvalPainter oldDelegate) =>
      isDetected != oldDelegate.isDetected || progress != oldDelegate.progress;
}
