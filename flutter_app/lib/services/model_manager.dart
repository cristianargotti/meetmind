import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages Whisper model download, caching, and verification.
///
/// Models are stored in the app's documents directory under `models/`.
/// SHA256 checksums verify model integrity after download.
class ModelManager {
  /// Whisper model catalog with sizes and checksums.
  static const Map<String, ModelInfo> catalog = {
    'tiny': ModelInfo(
      name: 'tiny',
      filename: 'ggml-tiny.bin',
      url:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin',
      sizeBytes: 77691713,
      sha256:
          'be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21',
      label: 'Tiny (75 MB)',
      description: 'Fastest, lower accuracy',
    ),
    'base': ModelInfo(
      name: 'base',
      filename: 'ggml-base.bin',
      url:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin',
      sizeBytes: 147951465,
      sha256:
          '60ed5bc3dd14eea856493d334b5bd4c7f1ab4254aa82a8854a2a638f59b064dc',
      label: 'Base (148 MB)',
      description: 'Recommended — best balance',
    ),
    'small': ModelInfo(
      name: 'small',
      filename: 'ggml-small.bin',
      url:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin',
      sizeBytes: 487601967,
      sha256:
          '1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1c5e6ae1ac',
      label: 'Small (466 MB)',
      description: 'Most accurate, slower',
    ),
  };

  /// Default model to use.
  static const String defaultModel = 'base';

  /// Get the models directory path.
  Future<Directory> get _modelsDir async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory modelsDir = Directory('${appDir.path}/models');
    if (!modelsDir.existsSync()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  /// Check if a model is already downloaded and verified.
  Future<bool> isModelAvailable(String modelName) async {
    final String? path = await getModelPath(modelName);
    return path != null;
  }

  /// Get the local file path for a downloaded model.
  ///
  /// Returns null if the model isn't downloaded or fails verification.
  Future<String?> getModelPath(String modelName) async {
    final ModelInfo? info = catalog[modelName];
    if (info == null) return null;

    final Directory dir = await _modelsDir;
    final File file = File('${dir.path}/${info.filename}');

    if (!file.existsSync()) return null;

    // Quick size check (full SHA256 is expensive)
    final int fileSize = await file.length();
    if (fileSize != info.sizeBytes) {
      debugPrint(
        '[ModelManager] Size mismatch for $modelName: '
        '$fileSize != ${info.sizeBytes}',
      );
      await file.delete();
      return null;
    }

    return file.path;
  }

  /// Download a model with progress reporting.
  ///
  /// [onProgress] receives values from 0.0 to 1.0.
  /// Returns the local file path on success.
  Future<String> downloadModel(
    String modelName, {
    void Function(double progress)? onProgress,
  }) async {
    final ModelInfo? info = catalog[modelName];
    if (info == null) {
      throw ModelManagerException('Unknown model: $modelName');
    }

    final Directory dir = await _modelsDir;
    final File file = File('${dir.path}/${info.filename}');
    final File tempFile = File('${file.path}.tmp');

    try {
      final HttpClient client = HttpClient();
      final HttpClientRequest request = await client.getUrl(
        Uri.parse(info.url),
      );
      final HttpClientResponse response = await request.close();

      if (response.statusCode != 200) {
        throw ModelManagerException(
          'Download failed: HTTP ${response.statusCode}',
        );
      }

      final int contentLength = response.contentLength > 0
          ? response.contentLength
          : info.sizeBytes;

      final IOSink sink = tempFile.openWrite();
      int downloaded = 0;

      await for (final List<int> chunk in response) {
        sink.add(chunk);
        downloaded += chunk.length;
        onProgress?.call(downloaded / contentLength);
      }

      await sink.flush();
      await sink.close();
      client.close();

      // Verify SHA256
      debugPrint('[ModelManager] Verifying SHA256 for $modelName...');
      final Digest hash = await _computeSha256(tempFile);
      if (hash.toString() != info.sha256) {
        await tempFile.delete();
        throw ModelManagerException(
          'SHA256 mismatch for $modelName. '
          'Expected: ${info.sha256}, Got: $hash',
        );
      }

      // Rename temp → final
      await tempFile.rename(file.path);
      debugPrint('[ModelManager] Model $modelName ready at ${file.path}');
      return file.path;
    } catch (e) {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }

  /// Delete a downloaded model.
  Future<void> deleteModel(String modelName) async {
    final String? path = await getModelPath(modelName);
    if (path != null) {
      await File(path).delete();
      debugPrint('[ModelManager] Deleted model: $modelName');
    }
  }

  /// Get total disk usage of downloaded models.
  Future<int> totalDiskUsage() async {
    final Directory dir = await _modelsDir;
    int total = 0;
    if (dir.existsSync()) {
      await for (final FileSystemEntity entity in dir.list()) {
        if (entity is File) {
          total += await entity.length();
        }
      }
    }
    return total;
  }

  Future<Digest> _computeSha256(File file) async {
    return compute(_sha256File, file.path);
  }

  static Digest _sha256File(String path) {
    final File file = File(path);
    final List<int> bytes = file.readAsBytesSync();
    return sha256.convert(bytes);
  }
}

/// Metadata for a Whisper model.
class ModelInfo {
  /// Create model metadata.
  const ModelInfo({
    required this.name,
    required this.filename,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
    required this.label,
    required this.description,
  });

  /// Model identifier (e.g., "base").
  final String name;

  /// Filename for local storage.
  final String filename;

  /// Download URL (HuggingFace).
  final String url;

  /// Expected file size in bytes.
  final int sizeBytes;

  /// Expected SHA256 checksum.
  final String sha256;

  /// Human-readable label.
  final String label;

  /// Human-readable description.
  final String description;

  /// Size in MB.
  double get sizeMB => sizeBytes / (1024 * 1024);
}

/// Exception thrown by ModelManager operations.
class ModelManagerException implements Exception {
  /// Create a ModelManagerException with a message.
  const ModelManagerException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'ModelManagerException: $message';
}
