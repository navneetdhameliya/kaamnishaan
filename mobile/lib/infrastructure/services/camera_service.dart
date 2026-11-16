import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../shared/app_logger.dart';

enum CameraOpenResult { ready, denied, unavailable }

/// The phone camera for proof photos (M20). Screens use this, never the plugin, so tests can fake it.
abstract class ICameraService {
  Future<CameraOpenResult> open();

  /// The live picture, filling its box (cropped, not stretched).
  Widget preview();

  /// Takes a photo and returns its file path, or null if it failed.
  Future<String?> takePicture();

  Future<void> close();
}

class CameraService implements ICameraService {
  CameraController? _controller;

  @override
  Future<CameraOpenResult> open() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhereOrNull((c) => c.lensDirection == CameraLensDirection.back) ?? cameras.firstOrNull;
      if (back == null) return CameraOpenResult.unavailable;
      await close();
      final controller = CameraController(
        back,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      _controller = controller;
      return CameraOpenResult.ready;
    } on CameraException catch (e) {
      AppLogger.error('Camera did not open', error: e);
      return e.code.startsWith('CameraAccess') ? CameraOpenResult.denied : CameraOpenResult.unavailable;
    } catch (e) {
      AppLogger.error('Camera did not open', error: e);
      return CameraOpenResult.unavailable;
    }
  }

  @override
  Widget preview() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return const ColoredBox(color: Colors.black);
    final size = c.value.previewSize;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          // the preview size is given in landscape
          width: size?.height ?? 1080,
          height: size?.width ?? 1920,
          child: CameraPreview(c),
        ),
      ),
    );
  }

  @override
  Future<String?> takePicture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture) return null;
    try {
      return (await c.takePicture()).path;
    } catch (e) {
      AppLogger.error('Taking a photo failed', error: e);
      return null;
    }
  }

  @override
  Future<void> close() async {
    final c = _controller;
    _controller = null;
    await c?.dispose();
  }
}
