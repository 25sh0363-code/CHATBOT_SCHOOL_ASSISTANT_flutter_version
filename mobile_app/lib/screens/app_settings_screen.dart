import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/file_selection_service.dart';
import '../services/local_store_service.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({
    super.key,
    required this.storeService,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final LocalStoreService storeService;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FileSelectionService _fileSelectionService = FileSelectionService();

  bool _loading = true;
  bool _updatingPhoto = false;
  Uint8List? _avatarBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await widget.storeService.loadProfileName();
    final avatarBase64 = await widget.storeService.loadProfilePhotoBase64();

    Uint8List? photoBytes;
    if (avatarBase64 != null && avatarBase64.isNotEmpty) {
      try {
        photoBytes = base64Decode(avatarBase64);
      } catch (_) {
        photoBytes = null;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _nameController.text = name;
      _avatarBytes = photoBytes;
      _loading = false;
    });
  }

  Future<void> _saveName() async {
    await widget.storeService.saveProfileName(_nameController.text.trim());
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Name updated.')),
    );
  }

  Future<void> _pickProfilePhoto() async {
    if (_updatingPhoto) {
      return;
    }

    setState(() => _updatingPhoto = true);
    final picked = await _fileSelectionService.pickFiles(
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'heic', 'heif'],
      allowMultiple: false,
      dialogLabel: 'Profile photo',
    );

    if (picked.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() => _updatingPhoto = false);
      return;
    }

    final bytes = picked.first.bytes;
    await widget.storeService.saveProfilePhotoBase64(base64Encode(bytes));
    if (!mounted) {
      return;
    }
    setState(() {
      _avatarBytes = bytes;
      _updatingPhoto = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile photo updated.')),
    );
  }

  Future<void> _removeProfilePhoto() async {
    await widget.storeService.saveProfilePhotoBase64(null);
    if (!mounted) {
      return;
    }
    setState(() {
      _avatarBytes = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile photo removed.')),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage:
                      _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                  child: _avatarBytes == null
                      ? Icon(Icons.tune_rounded,
                          color: theme.colorScheme.primary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Profile, theme, and preferences.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: theme.colorScheme.primaryContainer,
                      ),
                      child: Icon(
                        Icons.badge_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Profile',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: _avatarBytes != null
                          ? MemoryImage(_avatarBytes!)
                          : null,
                      child: _avatarBytes == null
                          ? Icon(
                              Icons.person_rounded,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed:
                                _updatingPhoto ? null : _pickProfilePhoto,
                            icon: _updatingPhoto
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.image_outlined),
                            label: const Text('Change Photo'),
                          ),
                          if (_avatarBytes != null)
                            TextButton.icon(
                              onPressed: _removeProfilePhoto,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remove'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saveName,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Name'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            title: Text(
              'Dark mode',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text('Use the dark app appearance'),
            secondary: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: theme.colorScheme.secondaryContainer,
              ),
              child: Icon(
                widget.isDarkMode
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            value: widget.isDarkMode,
            onChanged: (_) => widget.onToggleTheme(),
          ),
        ),
      ],
    );
  }
}
