import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../providers/profile_provider.dart';
import '../supabase_client.dart';
import '../theme.dart';
import '../services/cloudinary.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  String? _avatarUrl;
  XFile? _pendingImageFile;
  bool _avatarChanged = false;
  String? _initialUsername;
  bool _usernameAvailable = true;
  bool _checkingUsername = false;
  bool _saving = false;
  bool _uploading = false;
  Timer? _usernameTimer;
  bool _initialized = false;

  void _populateFromProfile(Profile profile) {
    if (_initialized) return;
    _initialized = true;
    _firstNameController.text = profile.firstName ?? '';
    _lastNameController.text = profile.lastName ?? '';
    _usernameController.text = profile.username ?? '';
    _initialUsername = profile.username ?? '';
    _avatarUrl = profile.avatarUrl;
  }

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile != null) {
      _populateFromProfile(profile);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _usernameTimer?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameTimer?.cancel();
    if (value.trim() == _initialUsername) {
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = true;
      });
      return;
    }
    if (value.trim().length < 3) {
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = false;
      });
      return;
    }
    setState(() => _checkingUsername = true);
    _usernameTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final res = await supabase.functions.invoke(
          'check-username',
          body: {'username': value.trim()},
        );
        if (!mounted) return;
        setState(() {
          _checkingUsername = false;
          _usernameAvailable = res.data['available'] == true;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _checkingUsername = false;
          _usernameAvailable = false;
        });
      }
    });
  }

  bool _hasChanges() {
    if (!_initialized) return false;
    final profile = ref.read(profileProvider).valueOrNull;
    if (_avatarChanged) return true;
    if (_firstNameController.text.trim() != (profile?.firstName ?? '')) return true;
    if (_lastNameController.text.trim() != (profile?.lastName ?? '')) return true;
    if (_usernameController.text.trim() != (profile?.username ?? '')) return true;
    return false;
  }

  Future<void> _handleBack() async {
    if (_hasChanges()) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('You have unsaved changes that will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (shouldDiscard != true || !mounted) return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      try {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      } catch (_) {}
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;
    // Stage image locally: zero network calls to Cloudinary or Supabase
    setState(() {
      _pendingImageFile = picked;
      _avatarChanged = true;
    });
  }

  Future<void> _save() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final username = _usernameController.text.trim();

    if (firstName.isEmpty) {
      _showError('First name is required.');
      return;
    }
    if (lastName.isEmpty) {
      _showError('Last name is required.');
      return;
    }
    if (username.isEmpty) {
      _showError('Username is required.');
      return;
    }
    if (!_usernameAvailable) {
      _showError('Username is already taken.');
      return;
    }

    setState(() => _saving = true);
    String? newlyUploadedUrl;
    try {
      if (_avatarChanged && _pendingImageFile != null) {
        setState(() => _uploading = true);
        try {
          newlyUploadedUrl = await uploadToCloudinary(_pendingImageFile!);
        } finally {
          if (mounted) setState(() => _uploading = false);
        }
      }

      final updates = <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        if (username != _initialUsername) 'username': username,
        'avatar_url': ?newlyUploadedUrl,
      };

      try {
        await supabase
            .from('profiles')
            .update(updates)
            .eq('id', supabase.auth.currentSession!.user.id);
      } catch (dbErr) {
        // Safe Cleanup: Database write failed. Destroy newly uploaded orphan asset
        if (newlyUploadedUrl != null) {
          try {
            await supabase.functions.invoke(
              'delete-media',
              body: {'asset_url': newlyUploadedUrl},
            );
          } catch (_) {
            // Cleanup error logged, existing DB avatar untouched
          }
        }
        rethrow;
      }

      final _ = await ref.refresh(profileProvider.future);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        try {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        } catch (_) {}
      }
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    if (!_initialized && profileAsync.hasValue && profileAsync.value != null) {
      _populateFromProfile(profileAsync.value!);
    }
    ImageProvider? imageProvider;
    if (_pendingImageFile != null) {
      if (kIsWeb) {
        imageProvider = NetworkImage(_pendingImageFile!.path);
      } else {
        imageProvider = FileImage(File(_pendingImageFile!.path));
      }
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_avatarUrl!);
    }

    return PopScope(
      canPop: !_hasChanges(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
        ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _uploading ? null : _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: CluvoTheme.primary.withValues(alpha: 0.15),
                    backgroundImage: imageProvider,
                    child: imageProvider == null
                        ? Text(
                            _firstNameController.text.isNotEmpty
                                ? _firstNameController.text[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: CluvoTheme.primary,
                            ),
                          )
                        : null,
                  ),
                  if (_uploading)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black26,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: CluvoTheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _uploading ? null : _pickImage,
              child: Text(
                _uploading
                    ? 'Uploading...'
                    : (_pendingImageFile != null
                        ? 'New photo selected (tap to change)'
                        : 'Tap to change photo'),
                style: TextStyle(
                  fontSize: 12,
                  color: context.cluvoTextSecondary,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildLabel('First Name'),
            const SizedBox(height: 6),
            TextField(
              controller: _firstNameController,
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 20),
            _buildLabel('Last Name'),
            const SizedBox(height: 6),
            TextField(
              controller: _lastNameController,
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 20),
            _buildLabel('Username'),
            const SizedBox(height: 6),
            TextField(
              controller: _usernameController,
              onChanged: _onUsernameChanged,
              decoration: _inputDecoration().copyWith(
                suffixIcon: _checkingUsername
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _usernameController.text.trim() != _initialUsername
                    ? Icon(
                        _usernameAvailable ? Icons.check_circle : Icons.cancel,
                        color: _usernameAvailable ? Colors.green : Colors.red,
                        size: 20,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: context.cluvoTextPrimary,
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: context.cluvoSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.cluvoBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.cluvoBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: CluvoTheme.primary, width: 1.5),
      ),
    );
  }
}
