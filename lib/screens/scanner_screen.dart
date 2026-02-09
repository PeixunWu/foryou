import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../app_state.dart' show AppState, ScanMode;
import '../services/gemini_service.dart' show ScanAnalysis;

enum ScannerMode { pill, skin, food }

enum CameraState {
  unknown,
  loading,
  unavailable,
  permissionDenied,
  available,
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  ScannerMode _mode = ScannerMode.pill;
  String _description = 'Center the pill for more accurate identification';
  bool _analyzing = false;
  CameraState _cameraState = CameraState.unknown;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  File? _capturedFile;

  @override
  void initState() {
    super.initState();
    _handlePreferredMode();
    _initCamera();
  }

  void _handlePreferredMode() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.preferredScannerMode != null) {
        setState(() {
          switch (state.preferredScannerMode!) {
            case ScanMode.pill:
              _mode = ScannerMode.pill;
              _description = 'Center the pill for more accurate identification';
              break;
            case ScanMode.skin:
              _mode = ScannerMode.skin;
              _description = 'Frame your skin area';
              break;
            case ScanMode.food:
              _mode = ScannerMode.food;
              _description = 'Center the food item';
              break;
          }
        });
        state.preferredScannerMode = null; // Clear after use
      }
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    if (!mounted) return;
    setState(() => _cameraState = CameraState.loading);

    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final result = await Permission.camera.request();
      if (!mounted) return;
      if (!result.isGranted) {
        setState(() => _cameraState = CameraState.permissionDenied);
        return;
      }
    }

    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) setState(() => _cameraState = CameraState.unavailable);
        return;
      }
      await _startCamera();
      if (mounted) setState(() => _cameraState = CameraState.available);
    } catch (_) {
      if (mounted) setState(() => _cameraState = CameraState.unavailable);
    }
  }

  /// Asks for camera permission via the iOS system popup (NSCameraUsageDescription). Does not open Settings.
  Future<void> _requestCameraPermission() async {
    if (!mounted) return;
    
    try {
      final status = await Permission.camera.status;
      if (status.isGranted) {
        await _initCamera();
        return;
      }
      
      // On iOS, if permission was previously denied (not permanently), request() might not show dialog again
      // But we still try - if it's the first time or if user hasn't seen the dialog, it will show
      setState(() => _cameraState = CameraState.loading);
      
      final result = await Permission.camera.request();
      if (!mounted) return;
      
      if (result.isGranted) {
        await _initCamera();
      } else {
        setState(() => _cameraState = CameraState.permissionDenied);
        if (result.isPermanentlyDenied && mounted) {
          // Permanently denied - dialog won't show, guide to Settings
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera access was denied. Tap "Open Settings" to enable it.'),
              duration: Duration(seconds: 4),
            ),
          );
        } else if (mounted) {
          // Denied but not permanently - might not show dialog on iOS if already denied once
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera access is required. If you don\'t see a prompt, check Settings.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cameraState = CameraState.permissionDenied);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error requesting camera: $e')),
        );
      }
    }
  }

  Future<void> _startCamera() async {
    if (_cameras == null || _cameras!.isEmpty) return;
    _cameraController?.dispose();
    final camera = _cameras![_selectedCameraIndex % _cameras!.length];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _switchCamera() async {
    if (_cameraState != CameraState.available || _cameras == null || _cameras!.length < 2) {
      if (_cameraState == CameraState.permissionDenied) {
        await _requestCameraPermission();
        return;
      }
      if (_cameraState == CameraState.unavailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera not found.')),
        );
      }
      return;
    }
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    await _startCamera();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (file != null && mounted) {
      final bytes = await file.readAsBytes();
      await _analyzeAndNavigate(bytes);
    }
  }

  Future<void> _captureFromCamera() async {
    if (_cameraState != CameraState.available || _cameraController == null) {
      if (_cameraState == CameraState.permissionDenied) {
        await _requestCameraPermission();
        return;
      }
      if (_cameraState == CameraState.unavailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera not found. Use photo album instead.')),
        );
      }
      return;
    }
    try {
      final XFile file = await _cameraController!.takePicture();
      if (mounted) {
        setState(() {
          _capturedFile = File(file.path);
        });
        final bytes = await file.readAsBytes();
        await _analyzeAndNavigate(bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture: $e')),
        );
      }
    }
  }

  void _onCaptureButtonTap() {
    if (_cameraState == CameraState.available && _cameraController != null) {
      _captureFromCamera();
    } else {
      _captureFromCamera();
    }
  }

  Future<void> _onTurnButtonTap() async {
    if (_cameraState == CameraState.available) {
      await _switchCamera();
    } else if (_cameraState == CameraState.permissionDenied) {
      await _requestCameraPermission();
    } else if (_cameraState == CameraState.unavailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not found.')),
      );
    }
  }

  Future<void> _analyzeAndNavigate(List<int> bytes) async {
    if (!mounted) return;
    setState(() {
      _analyzing = true;
      _description = 'Analyzing...';
    });
    final state = context.read<AppState>();
    final gemini = state.gemini;
    ScanAnalysis analysis;
    try {
      final imageBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      switch (_mode) {
        case ScannerMode.pill:
          analysis = await gemini.analyzePill(imageBytes, state.userSkinProfile);
          break;
        case ScannerMode.skin:
          analysis = await gemini.analyzeSkin(imageBytes, state.userSkinProfile);
          break;
        case ScannerMode.food:
          analysis = await gemini.analyzeFood(imageBytes, state.userSkinProfile);
          break;
      }
      state.setScanResult(
        analysis,
        imageBytes,
        _mode == ScannerMode.pill
            ? ScanMode.pill
            : _mode == ScannerMode.skin
                ? ScanMode.skin
                : ScanMode.food,
      );
      if (!mounted) return;
      await Navigator.of(context).pushNamed('/analysis');
      if (mounted) {
        setState(() {
          _analyzing = false;
          _capturedFile = null;
          // Reset description based on mode
          switch (_mode) {
             case ScannerMode.pill:
               _description = 'Center the pill for more accurate identification';
               break;
             case ScannerMode.skin:
               _description = 'Frame your skin area';
               break;
             case ScannerMode.food:
               _description = 'Center the food item';
               break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _description = 'Analysis failed. Try again.';
          _analyzing = false;
          _capturedFile = null;
        });
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  String get _statusMessage {
    switch (_cameraState) {
      case CameraState.unavailable:
        return 'Camera not found';
      case CameraState.permissionDenied:
      case CameraState.loading:
        return 'Preparing camera...';
      default:
        return _description;
    }
  }

  bool get _showLiveCamera =>
      _cameraState == CameraState.available && _cameraController != null && _cameraController!.value.isInitialized;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black87),
          if (_capturedFile != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: Image.file(_capturedFile!),
              ),
            )
          else if (_showLiveCamera)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1,
                  height: _cameraController!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          _buildDescriptionBar(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: _cameraState == CameraState.permissionDenied,
              child: _buildBottomControls(accent),
            ),
          ),
          // Overlay must be last in Stack to be on top and clickable
          if (_cameraState == CameraState.permissionDenied) _buildPermissionDeniedOverlay(),
          if (_analyzing) _buildAnalyzingOverlay(),
        ],
      ),
    );
  }

  Widget _buildAnalyzingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 24),
              Text(
                'Analyzing Item...',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Our AI is analyzing your photo...',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedOverlay() {
    return Positioned.fill(
      child: Material(
        color: Colors.black87,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 64, color: Colors.white54),
                  const SizedBox(height: 16),
                  Text(
                    'Camera access needed',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap below to see the system prompt to allow camera access.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _analyzing ? null : () async {
                      await _requestCameraPermission();
                    },
                    icon: const Icon(Icons.camera_alt, size: 20),
                    label: const Text('Allow camera access'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _analyzing ? null : () async {
                      await openAppSettings();
                    },
                    icon: const Icon(Icons.settings, size: 18, color: Colors.white54),
                    label: Text(
                      'Open Settings',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionBar() {
    return Positioned(
      left: 20,
      right: 20,
      top: MediaQuery.of(context).padding.top + 24,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _analyzing
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Text(_statusMessage, style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                )
              : Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(Color accent) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black54],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeChip(
                label: 'Identify Pill',
                selected: _mode == ScannerMode.pill,
                onTap: () => setState(() {
                  _mode = ScannerMode.pill;
                  _description = 'Center the pill for more accurate identification';
                }),
              ),
              _ModeChip(
                label: 'Analyze Skin',
                selected: _mode == ScannerMode.skin,
                onTap: () => setState(() {
                  _mode = ScannerMode.skin;
                  _description = 'Frame your skin area';
                }),
              ),
              _ModeChip(
                label: 'Check Food',
                selected: _mode == ScannerMode.food,
                onTap: () => setState(() {
                  _mode = ScannerMode.food;
                  _description = 'Center the food item';
                }),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.photo_library, color: Colors.white, size: 28),
                onPressed: _analyzing ? null : _pickImage,
              ),
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _analyzing ? null : _onCaptureButtonTap,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 72,
                    height: 72,
                    child: Icon(Icons.camera_alt, size: 36, color: Colors.black87),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 28),
                onPressed: _analyzing ? null : _onTurnButtonTap,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield, color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              Text(
                'SECURE AI PROCESSING',
                style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black87 : Colors.white,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

