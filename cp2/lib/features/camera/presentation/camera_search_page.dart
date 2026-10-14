import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app.dart';
import '../../candidates/presentation/candidate_confirmation_page.dart';
import '../../search/domain/hotel_candidate.dart';
import '../../search/domain/hotel_repository.dart';

class CameraSearchPage extends StatefulWidget {
  const CameraSearchPage({super.key, required this.repository});

  final HotelRepository repository;

  @override
  State<CameraSearchPage> createState() => _CameraSearchPageState();
}

class _CameraSearchPageState extends State<CameraSearchPage>
    with WidgetsBindingObserver {
  final _imagePicker = ImagePicker();
  CameraController? _cameraController;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _flashEnabled = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera(cameraIndex: _cameraIndex);
    }
  }

  Future<void> _initializeCamera({int cameraIndex = 0}) async {
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _cameraError = null;
      });
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
          'no_camera',
          'No camera is available on this device.',
        );
      }

      _cameras = cameras;
      _cameraIndex = cameraIndex.clamp(0, cameras.length - 1);
      final previousController = _cameraController;
      _cameraController = null;
      await previousController?.dispose();

      final controller = CameraController(
        cameras[_cameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isInitializing = false;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _cameraError = _friendlyCameraError(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _cameraError =
            'The camera could not start. Use a stored image instead.';
      });
    }
  }

  String _friendlyCameraError(CameraException error) {
    return switch (error.code) {
      'CameraAccessDenied' ||
      'CameraAccessDeniedWithoutPrompt' =>
        'Camera access is off. Allow camera permission in Android settings or use the gallery.',
      _ => 'The camera could not start. Use a stored image instead.',
    };
  }

  Future<void> _captureImage() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      await _useSystemCamera();
      return;
    }

    try {
      final image = await controller.takePicture();
      await _processImage(image, CandidateSource.camera);
    } on CameraException {
      await _useSystemCamera();
    }
  }

  Future<void> _useSystemCamera() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1800,
      imageQuality: 88,
    );
    if (image != null) {
      await _processImage(image, CandidateSource.camera);
    }
  }

  Future<void> _pickFromGallery() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      imageQuality: 88,
    );
    if (image != null) {
      await _processImage(image, CandidateSource.gallery);
    }
  }

  Future<void> _processImage(XFile image, CandidateSource source) async {
    setState(() => _isProcessing = true);
    try {
      final candidates = await widget.repository.rankVisualCandidates(
        image.path,
        source: source,
      );
      if (!mounted) return;
      setState(() => _isProcessing = false);

      await Navigator.of(context).pushNamed(
        AppRoutes.candidates,
        arguments: CandidatePageArguments.image(
          source: source,
          candidates: candidates,
        ),
      );
    } on HotelRepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.userMessage)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The selected image could not be analyzed.'),
        ),
      );
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    final nextValue = !_flashEnabled;
    await controller.setFlashMode(nextValue ? FlashMode.torch : FlashMode.off);
    if (mounted) setState(() => _flashEnabled = nextValue);
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final nextIndex = (_cameraIndex + 1) % _cameras.length;
    await _initializeCamera(cameraIndex: nextIndex);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _CameraSurface(
            controller: _cameraController,
            isInitializing: _isInitializing,
            error: _cameraError,
            onFallbackCamera: _useSystemCamera,
          ),
          const _ViewfinderOverlay(),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _CircleControl(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icons.arrow_back,
                    ),
                    const Spacer(),
                    _CircleControl(
                      tooltip:
                          _flashEnabled ? 'Turn flash off' : 'Turn flash on',
                      onPressed: _toggleFlash,
                      icon: _flashEnabled ? Icons.flash_on : Icons.flash_off,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                color: Colors.black.withValues(alpha: 0.72),
                padding: const EdgeInsets.fromLTRB(28, 14, 28, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _LabeledControl(
                      label: 'Gallery',
                      icon: Icons.photo_library_outlined,
                      onPressed: _pickFromGallery,
                    ),
                    Semantics(
                      button: true,
                      label: 'Capture hotel image',
                      child: InkResponse(
                        onTap: _isProcessing ? null : _captureImage,
                        radius: 42,
                        child: Container(
                          width: 74,
                          height: 74,
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF1769E0),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _LabeledControl(
                      label: 'Switch',
                      icon: Icons.cameraswitch_outlined,
                      onPressed: _switchCamera,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isProcessing)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.6),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 14),
                        Text(
                          'Analyzing image clues...',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text('Preparing the top three candidates.'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CameraSurface extends StatelessWidget {
  const _CameraSurface({
    required this.controller,
    required this.isInitializing,
    required this.error,
    required this.onFallbackCamera,
  });

  final CameraController? controller;
  final bool isInitializing;
  final String? error;
  final VoidCallback onFallbackCamera;

  @override
  Widget build(BuildContext context) {
    if (controller != null && controller!.value.isInitialized) {
      return Center(child: CameraPreview(controller!));
    }

    return ColoredBox(
      color: const Color(0xFF152238),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isInitializing) ...[
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'Starting camera...',
                  style: TextStyle(color: Colors.white),
                ),
              ] else ...[
                const Icon(
                  Icons.no_photography_outlined,
                  color: Colors.white,
                  size: 44,
                ),
                const SizedBox(height: 12),
                Text(
                  error ?? 'Camera preview is unavailable.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onFallbackCamera,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Use system camera'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewfinderOverlay extends StatelessWidget {
  const _ViewfinderOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 70),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 286,
                  height: 340,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Align a hotel signboard, building, or nearby landmark inside the frame.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleControl extends StatelessWidget {
  const _CircleControl({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.55),
        foregroundColor: Colors.white,
      ),
      icon: Icon(icon),
    );
  }
}

class _LabeledControl extends StatelessWidget {
  const _LabeledControl({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: label,
            onPressed: onPressed,
            color: Colors.white,
            icon: Icon(icon),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
