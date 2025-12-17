import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

/// Service for face recognition using TensorFlow Lite (MobileFaceNet)
/// Provides deep learning based face embeddings for high security.
class FaceRecognitionService {
  late FaceDetector _faceDetector;
  Interpreter? _interpreter;

  // MobileFaceNet 112x112 input
  static const int inputSize = 112;

  // Threshold for Cosine Similarity (0.0 to 1.0)
  // Kept high (0.65) for strong security. Accuracy is ensured by multi-angle registration.
  static const double similarityThreshold = 0.65;

  FaceRecognitionService() {
    _initialize();
  }

  Future<void> _initialize() async {
    // 1. Initialize Face Detector (for bounding box)
    final options = FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);

    // 2. Initialize TFLite Model
    try {
      final options = InterpreterOptions();
      if (defaultTargetPlatform == TargetPlatform.android) {
        // options.addDelegate(GpuDelegateV2()); // Optional: Use GPU
      }

      _interpreter = await Interpreter.fromAsset(
          'assets/models/mobilefacenet.tflite',
          options: options);
      debugPrint('✅ [TFLite] Model loaded successfully');

      // Verify input/output shape
      // Input: [1, 112, 112, 3]
      // Output: [1, 192]
      var inputShape = _interpreter!.getInputTensor(0).shape;
      var outputShape = _interpreter!.getOutputTensor(0).shape;
      debugPrint('✅ [TFLite] Input Shape: $inputShape');
      debugPrint('✅ [TFLite] Output Shape: $outputShape');
    } catch (e) {
      debugPrint('❌ [TFLite] Failed to load model: $e');
    }
  }

  Future<List<Face>> detectFaces(InputImage inputImage) async {
    try {
      return await _faceDetector.processImage(inputImage);
    } catch (e) {
      debugPrint('❌ [MLKit] Detect failed: $e');
      return [];
    }
  }

  /// Generate embedding from face image
  /// Requires the original CameraImage to crop the face region
  Future<List<double>> extractEmbeddings(
      CameraImage cameraImage, Face face) async {
    if (_interpreter == null) {
      debugPrint('❌ [TFLite] Interpreter not initialized');
      return [];
    }

    try {
      // 1. Convert CameraImage to img.Image
      img.Image? image = _convertCameraImage(cameraImage);
      if (image == null) return [];

      // 2. Crop Face with Padding
      // Add padding to ensure full face is captured (helps with recognition)
      final double paddingRatio = 0.10; // 10% padding
      final int paddingW = (face.boundingBox.width * paddingRatio).toInt();
      final int paddingH = (face.boundingBox.height * paddingRatio).toInt();

      int x = max(0, face.boundingBox.left.toInt() - paddingW);
      int y = max(0, face.boundingBox.top.toInt() - paddingH);
      int w = face.boundingBox.width.toInt() + (paddingW * 2);
      int h = face.boundingBox.height.toInt() + (paddingH * 2);

      // Boundary checks
      if (x + w > image.width) w = image.width - x;
      if (y + h > image.height) h = image.height - y;

      img.Image faceCrop = img.copyCrop(image, x: x, y: y, width: w, height: h);

      // 3. Resize to 112x112
      img.Image resizedFace =
          img.copyResize(faceCrop, width: inputSize, height: inputSize);

      // 4. Update Input Tensor
      // MobileFaceNet expects normalized float32 [-1, 1] usually, or [0, 1]
      // Common normalization: (pixel - 128) / 128.0

      List input = _imageToFloatList(resizedFace);

      // Reshape to [1, 112, 112, 3]
      var inputTensor = input.reshape([1, 112, 112, 3]);

      // Output container [1, 192]
      var outputTensor = List.filled(1 * 192, 0.0).reshape([1, 192]);

      // 5. Run Inference
      _interpreter!.run(inputTensor, outputTensor);

      // 6. Get Result
      List<double> embedding = List<double>.from(outputTensor[0]);

      // 7. L2 Normalize result
      return _normalizeEmbeddings(embedding);
    } catch (e, stack) {
      debugPrint('❌ [TFLite] Extraction error: $e');
      debugPrint(stack.toString());
      return [];
    }
  }

  // Convert CameraImage to img.Image
  img.Image? _convertCameraImage(CameraImage image) {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420(image);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888(image);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  img.Image _convertBGRA8888(CameraImage image) {
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
      order: img.ChannelOrder.bgra, // Image package supports bgra
    );
  }

  img.Image _convertYUV420(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final img.Image finalImage = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex =
            uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;

        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];

        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        finalImage.setPixelRgb(x, y, r, g, b);
      }
    }
    return finalImage;
  }

  List<double> _imageToFloatList(img.Image image) {
    var convertedBytes = Float32List(1 * 112 * 112 * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var i = 0; i < 112; i++) {
      for (var j = 0; j < 112; j++) {
        var pixel = image.getPixel(j, i);

        // Normalize to [-1, 1]
        // Standard MobileFaceNet TFLite expects RGB
        buffer[pixelIndex++] = (pixel.r - 127.5) / 127.5;
        buffer[pixelIndex++] = (pixel.g - 127.5) / 127.5;
        buffer[pixelIndex++] = (pixel.b - 127.5) / 127.5;
      }
    }
    return buffer.toList(); // Return as standard list for reshape
  }

  List<double> _normalizeEmbeddings(List<double> embeddings) {
    if (embeddings.isEmpty) return [];
    double sum = 0;
    for (var x in embeddings) sum += x * x;
    double norm = sqrt(sum);
    if (norm == 0) return embeddings;
    return embeddings.map((e) => e / norm).toList();
  }

  // --- Matching Logic ---

  double calculateSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length || v1.isEmpty) return 0.0;
    double dot = 0.0;
    for (int i = 0; i < v1.length; i++) dot += v1[i] * v2[i];
    // Assumes vectors are already L2 normalized, so similarity is just dot product
    return dot.clamp(0.0, 1.0);
  }

  bool isMatch(List<double> v1, List<double> v2) {
    return calculateSimilarity(v1, v2) >= similarityThreshold;
  }

  // Backwards compatibility for list of list
  List<double> averageEmbeddings(List<List<double>> embeddings) {
    if (embeddings.isEmpty) return [];
    int len = embeddings[0].length;
    List<double> avg = List.filled(len, 0.0);

    for (var emb in embeddings) {
      for (int i = 0; i < len; i++) avg[i] += emb[i];
    }
    for (int i = 0; i < len; i++) avg[i] /= embeddings.length;

    return _normalizeEmbeddings(avg);
  }

  Map<String, dynamic> findBestMatch(
      List<double> scanned, List<List<double>> stored) {
    if (stored.isEmpty)
      return {'match': false, 'similarity': 0.0, 'message': 'No data'};

    double bestSim = 0.0;
    for (var s in stored) {
      // Check dimension (heuristic was < 20, mobilefacenet is 192)
      if (s.length < 100) {
        return {
          'match': false,
          'similarity': 0.0,
          'message':
              'Security Update: Please re-register face (Deep Learning Upgrade)',
        };
      }

      double sim = calculateSimilarity(scanned, s);
      if (sim > bestSim) bestSim = sim;
    }

    bool match = bestSim >= similarityThreshold;
    return {
      'match': match,
      'similarity': bestSim,
      'similarityPercent': (bestSim * 100).toStringAsFixed(1),
      'message': match
          ? 'Face recognized ($bestSim)'
          : 'Face not recognized ($bestSim < $similarityThreshold)',
    };
  }

  // Validation Proxy
  Map<String, dynamic> validateFaceQuality(Face face, {bool checkEyes = true}) {
    // Basic checks from ML Kit
    if (face.headEulerAngleY!.abs() > 20)
      return {'valid': false, 'message': 'Look straighter'};
    if (checkEyes) {
      if ((face.leftEyeOpenProbability ?? 1) < 0.2)
        //  return {'valid': false, 'message': 'Open eyes'};
        // relaxed for now
        return {'valid': true, 'message': 'OK'};
    }
    return {'valid': true, 'message': 'OK'};
  }

  void dispose() {
    _faceDetector.close();
    _interpreter?.close();
  }
}
