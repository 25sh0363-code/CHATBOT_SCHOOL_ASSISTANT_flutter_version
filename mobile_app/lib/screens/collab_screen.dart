import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/collab_message.dart';
import '../models/collab_room.dart';
import '../models/collab_user.dart';
import '../models/quick_note.dart';
import '../models/worksheet_record.dart';
import '../services/collab_api_service.dart';
import '../services/local_store_service.dart';

class CollabScreen extends StatefulWidget {
  const CollabScreen({super.key, required this.storeService});

  final LocalStoreService storeService;

  @override
  State<CollabScreen> createState() => _CollabScreenState();
}

class _CollabScreenState extends State<CollabScreen> {
  late final CollabApiService _collabApi;

  CollabUser? _user;
  List<CollabRoom> _rooms = <CollabRoom>[];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _collabApi = CollabApiService(baseUrl: AppConfig.backendBaseUrl);
    _restoreUser();
  }

  Future<void> _restoreUser() async {
    final savedUser = await widget.storeService.loadCollabUser();
    if (!mounted || savedUser == null) {
      return;
    }
    setState(() {
      _user = savedUser;
    });
    await _refreshRooms();
  }

  Future<void> _signIn() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign In To Collab'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  hintText: 'Leave empty for guest account',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (shouldContinue != true) {
      return;
    }

    setState(() => _loading = true);
    try {
      final user = await _collabApi.signInBasic(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _user = user;
      });
      await widget.storeService.saveCollabUser(user);
      await _refreshRooms();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshRooms() async {
    final user = _user;
    if (user == null) {
      return;
    }
    setState(() => _loading = true);
    try {
      final rooms = await _collabApi.getRooms(userEmail: user.email);
      if (!mounted) {
        return;
      }
      setState(() {
        _rooms = rooms;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load collab rooms: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signOut() async {
    await widget.storeService.clearCollabUser();
    if (!mounted) {
      return;
    }
    setState(() {
      _user = null;
      _rooms = <CollabRoom>[];
    });
  }

  Future<void> _createRoom() async {
    final user = _user;
    if (user == null) {
      return;
    }

    final nameController = TextEditingController();
    bool isPublic = true;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Collab'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Collab name'),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isPublic,
                    onChanged: (value) =>
                        setDialogState(() => isPublic = value),
                    title: const Text('Public room'),
                    subtitle: const Text('Anyone signed in can join'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) {
                      return;
                    }
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldCreate != true) {
      return;
    }

    try {
      final room = await _collabApi.createRoom(
        name: nameController.text.trim(),
        creatorEmail: user.email,
        creatorName: user.name,
        isPublic: isPublic,
      );
      if (!mounted) {
        return;
      }
      await _refreshRooms();
      await _openRoom(room);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create collab: $e')),
      );
    }
  }

  Future<void> _joinAndOpen(CollabRoom room) async {
    final user = _user;
    if (user == null) {
      return;
    }
    try {
      final joined = await _collabApi.joinRoom(
        roomId: room.id,
        userEmail: user.email,
        userName: user.name,
      );
      if (!mounted) {
        return;
      }
      await _refreshRooms();
      await _openRoom(joined);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not join collab: $e')),
      );
    }
  }

  Future<void> _deleteRoom(CollabRoom room) async {
    final user = _user;
    if (user == null) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Collab'),
          content: Text(
            'Delete "${room.name}" for everyone? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() => _loading = true);
    try {
      await _collabApi.deleteRoom(
        roomId: room.id,
        userEmail: user.email,
      );
      if (!mounted) {
        return;
      }
      await _refreshRooms();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted collab: ${room.name}')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete collab: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openRoom(CollabRoom room) async {
    final user = _user;
    if (user == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CollabRoomPage(
          room: room,
          user: user,
          collabApi: _collabApi,
          storeService: widget.storeService,
        ),
      ),
    );
    await _refreshRooms();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Collab Hub',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'Sign in, create or join collabs, chat, share notes or worksheets, and join a shared Meet link.',
                ),
                const SizedBox(height: 12),
                if (user == null)
                  FilledButton.icon(
                    onPressed: _loading ? null : _signIn,
                    icon: const Icon(Icons.login),
                    label: const Text('Sign In To Collab'),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      Chip(label: Text('Signed in: ${user.name}')),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _refreshRooms,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _signOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                      ),
                      FilledButton.icon(
                        onPressed: _loading ? null : _createRoom,
                        icon: const Icon(Icons.group_add_outlined),
                        label: const Text('Create Collab'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (user == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sign in to view and join collabs.'),
            ),
          )
        else if (_rooms.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No collab rooms yet. Create one to start.'),
            ),
          )
        else
          ..._rooms.map(
            (room) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(room.name),
                subtitle: Text(
                  '${room.memberCount} members • ${room.isPublic ? 'Public' : 'Private'}',
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    if (user.email == room.ownerEmail)
                      OutlinedButton(
                        onPressed: _loading ? null : () => _deleteRoom(room),
                        child: const Text('Delete'),
                      ),
                    FilledButton(
                      onPressed: _loading ? null : () => _joinAndOpen(room),
                      child: const Text('Join'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CollabRoomPage extends StatefulWidget {
  const _CollabRoomPage({
    required this.room,
    required this.user,
    required this.collabApi,
    required this.storeService,
  });

  final CollabRoom room;
  final CollabUser user;
  final CollabApiService collabApi;
  final LocalStoreService storeService;

  @override
  State<_CollabRoomPage> createState() => _CollabRoomPageState();
}

class _CollabRoomPageState extends State<_CollabRoomPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const int _maxSavedAttachmentBytesPerFile = 250 * 1024;
  static const int _maxSavedAttachmentBytesTotal = 600 * 1024;

  List<CollabMessage> _messages = <CollabMessage>[];
  CollabRoom? _room;
  Timer? _pollTimer;
  bool _busy = false;

  bool get _isOwner => (_room ?? widget.room).ownerEmail == widget.user.email;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() => _busy = true);
    }
    try {
      final messages = await widget.collabApi.getMessages(
        roomId: widget.room.id,
        userEmail: widget.user.email,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = messages;
      });
    } catch (_) {
      // Keep polling quiet for transient network issues.
    } finally {
      if (mounted && !silent) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _messageController.clear();
    try {
      await widget.collabApi.sendMessage(
        roomId: widget.room.id,
        userEmail: widget.user.email,
        userName: widget.user.name,
        text: text,
      );
      await _loadMessages(silent: true);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send message: $e')),
      );
    }
  }

  Future<void> _shareNote() async {
    final notes = await widget.storeService.loadQuickNotes();
    if (!mounted) {
      return;
    }
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No notes available to share.')),
      );
      return;
    }

    final note = await _pickNote(notes);
    if (note == null) {
      return;
    }

    try {
      await widget.collabApi.shareNote(
        roomId: widget.room.id,
        userEmail: widget.user.email,
        userName: widget.user.name,
        note: note,
      );
      await _loadMessages(silent: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share note: $e')),
      );
    }
  }

  Future<void> _shareWorksheet() async {
    final worksheets = await widget.storeService.loadWorksheets();
    if (!mounted) {
      return;
    }
    if (worksheets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No worksheets available to share.')),
      );
      return;
    }

    final worksheet = await _pickWorksheet(worksheets);
    if (worksheet == null) {
      return;
    }

    try {
      await widget.collabApi.shareWorksheet(
        roomId: widget.room.id,
        userEmail: widget.user.email,
        userName: widget.user.name,
        worksheet: worksheet,
      );
      await _loadMessages(silent: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share worksheet: $e')),
      );
    }
  }

  List<QuickNoteAttachment> _noteAttachmentsFromPayload(CollabMessage message) {
    return (message.payload['attachments'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => QuickNoteAttachment(
            name: item['name']?.toString() ?? '',
            base64Data: item['base64_data']?.toString() ?? '',
            mimeType:
                item['mime_type']?.toString() ?? 'application/octet-stream',
          ),
        )
        .where((item) => item.name.isNotEmpty && item.base64Data.isNotEmpty)
        .toList();
  }

  Future<File> _materializeAttachment(
    String sourceId,
    QuickNoteAttachment attachment,
  ) async {
    final cacheDir = await getTemporaryDirectory();
    final root = Directory('${cacheDir.path}/collab_note_files');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }

    final safeName = attachment.name
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final file = File('${root.path}/${sourceId}_$safeName');
    if (!await file.exists()) {
      final bytes = base64Decode(attachment.base64Data);
      await file.writeAsBytes(bytes, flush: true);
    }
    return file;
  }

  Future<void> _openSharedAttachment(
    CollabMessage message,
    QuickNoteAttachment attachment,
  ) async {
    try {
      final file = await _materializeAttachment(message.id, attachment);
      final result = await OpenFilex.open(file.path, type: attachment.mimeType);
      if (!mounted) {
        return;
      }
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${attachment.name}')),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: ${attachment.name}')),
      );
    }
  }

  IconData _iconForMimeType(String mimeType) {
    final mime = mimeType.toLowerCase();
    if (mime.contains('pdf')) {
      return Icons.picture_as_pdf_outlined;
    }
    if (mime.startsWith('image/')) {
      return Icons.image_outlined;
    }
    if (mime.contains('word') || mime.contains('document') || mime.contains('text')) {
      return Icons.description_outlined;
    }
    return Icons.attach_file_outlined;
  }

  String _normalizeMeetLink(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      return trimmed;
    }

    // Support links like meet.google.com/abc-defg-hij pasted without scheme.
    if (trimmed.startsWith('meet.google.com')) {
      return 'https://$trimmed';
    }

    return 'https://$trimmed';
  }

  Future<void> _setMeetLink() async {
    final controller = TextEditingController(text: _room?.meetLink ?? '');
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Google Meet Link'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText:
                  'Paste a meet.google.com link (or leave empty for meet.new)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    final normalizedLink = _normalizeMeetLink(controller.text);

    final room = await widget.collabApi.updateMeetLink(
      roomId: widget.room.id,
      userEmail: widget.user.email,
      userName: widget.user.name,
      meetLink: normalizedLink,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _room = room;
    });
    await _loadMessages(silent: true);
  }

  Future<void> _manageMembers() async {
    final room = _room ?? widget.room;
    final removableMembers = room.members
        .where((member) => member.email != widget.user.email)
        .toList();

    if (removableMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other members to remove.')),
      );
      return;
    }

    final member = await showDialog<CollabMember>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Manage Members'),
          content: SizedBox(
            width: 420,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: removableMembers.length,
              itemBuilder: (_, index) {
                final member = removableMembers[index];
                return ListTile(
                  title: Text(member.name),
                  subtitle: Text(member.email),
                  trailing: const Icon(Icons.person_remove_outlined),
                  onTap: () => Navigator.of(context).pop(member),
                );
              },
            ),
          ),
        );
      },
    );

    if (!mounted || member == null) {
      return;
    }

    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Member'),
          content: Text('Remove ${member.name} from this collab?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true) {
      return;
    }

    setState(() => _busy = true);
    try {
      final updatedRoom = await widget.collabApi.removeMember(
        roomId: room.id,
        ownerEmail: widget.user.email,
        memberEmail: member.email,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _room = updatedRoom;
      });
      await _loadMessages(silent: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed ${member.name} from the collab.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove member: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveSharedNote(CollabMessage message) async {
    try {
      final topic = message.payload['topic']?.toString().trim() ?? '';
      final content = message.payload['content']?.toString().trim() ?? '';
      if (topic.isEmpty || content.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This shared note is missing required content.')),
        );
        return;
      }

      final rawAttachments = _noteAttachmentsFromPayload(message);
      var savedBytesTotal = 0;
      final attachments = rawAttachments.where((item) {
        final estimatedBytes = (item.base64Data.length * 3) ~/ 4;
        if (estimatedBytes > _maxSavedAttachmentBytesPerFile) {
          return false;
        }
        if (savedBytesTotal + estimatedBytes > _maxSavedAttachmentBytesTotal) {
          return false;
        }
        savedBytesTotal += estimatedBytes;
        return true;
      }).toList();

      final notes = await widget.storeService.loadQuickNotes();
      final now = DateTime.now();
      final noteId = 'shared_note_${message.id}_${now.microsecondsSinceEpoch}';
      final savedTopic = topic;

      notes.insert(
        0,
        QuickNote(
          id: noteId,
          topic: savedTopic,
          content: content,
          createdAt: now,
          updatedAt: now,
          attachments: attachments,
        ),
      );

      // First try saving with retained attachments.
      try {
        await widget.storeService.saveQuickNotes(notes);
      } catch (_) {
        // Fallback: save without attachments to guarantee note text is persisted.
        notes[0] = QuickNote(
          id: noteId,
          topic: savedTopic,
          content: content,
          createdAt: now,
          updatedAt: now,
          attachments: const <QuickNoteAttachment>[],
        );
        try {
          await widget.storeService.saveQuickNotes(notes);
        } catch (_) {
          // Last-resort compaction for macOS/desktop storage pressure:
          // strip heavy attachments from older notes and keep newest note.
          final compacted = <QuickNote>[];
          for (var i = 0; i < notes.length; i++) {
            final item = notes[i];
            if (i == 0) {
              compacted.add(item);
              continue;
            }
            compacted.add(
              item.copyWith(
                attachments: const <QuickNoteAttachment>[],
                updatedAt: item.updatedAt,
              ),
            );
          }
          await widget.storeService.saveQuickNotes(compacted);
        }
      }

      final verification = await widget.storeService.loadQuickNotes();
      final exists = verification.any(
        (note) => note.id == noteId,
      );
      if (!exists) {
        throw Exception('Verification failed.');
      }

      if (!mounted) {
        return;
      }
      final droppedCount = rawAttachments.length - attachments.length;
      final suffix = droppedCount > 0
          ? ' (${droppedCount} large attachment${droppedCount == 1 ? '' : 's'} skipped for local save)'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved note: $savedTopic$suffix')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save shared note: $e')),
      );
    }
  }

  Future<void> _saveSharedWorksheet(CollabMessage message) async {
    final title = message.payload['title']?.toString().trim() ?? '';
    final subject = message.payload['subject']?.toString().trim() ?? '';
    final topic = message.payload['topic']?.toString().trim() ?? '';
    final questions =
        (message.payload['questions'] as List<dynamic>? ?? const [])
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();

    if (title.isEmpty ||
        subject.isEmpty ||
        topic.isEmpty ||
        questions.isEmpty) {
      return;
    }

    final worksheets = await widget.storeService.loadWorksheets();
    final existingIndex = worksheets.indexWhere(
      (worksheet) =>
          worksheet.title == title &&
          worksheet.subject == subject &&
          worksheet.topic == topic &&
          worksheet.questions.join('\n') == questions.join('\n'),
    );
    final now = DateTime.now();

    if (existingIndex >= 0) {
      worksheets.removeAt(existingIndex);
    }

    worksheets.insert(
      0,
      WorksheetRecord(
        id: 'shared_worksheet_${now.microsecondsSinceEpoch}',
        title: title,
        subject: subject,
        topic: topic,
        createdAt: now,
        questions: questions,
      ),
    );

    await widget.storeService.saveWorksheets(worksheets);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved worksheet: $title')),
    );
  }

  String _notePreview(String content) {
    final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 160) {
      return normalized;
    }
    return '${normalized.substring(0, 160)}...';
  }

  Widget? _messageAction(CollabMessage message) {
    if (message.messageType == 'note') {
      return TextButton.icon(
        onPressed: () => _saveSharedNote(message),
        icon: const Icon(Icons.download_outlined),
        label: const Text('Save Note'),
      );
    }

    if (message.messageType == 'worksheet') {
      return TextButton.icon(
        onPressed: () => _saveSharedWorksheet(message),
        icon: const Icon(Icons.download_outlined),
        label: const Text('Save Worksheet'),
      );
    }

    return null;
  }

  Future<void> _joinMeet() async {
    final link = _normalizeMeetLink(_room?.meetLink ?? '');
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No meet link is set for this collab yet.')),
      );
      return;
    }

    final uri = Uri.tryParse(link);
    if (uri == null || uri.host.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Meet link. Please set it again.')),
      );
      return;
    }

    final canLaunch = await canLaunchUrl(uri);
    if (!canLaunch) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Meet link on this device.')),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!launched) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<QuickNote?> _pickNote(List<QuickNote> notes) async {
    return showDialog<QuickNote>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Share Note'),
          content: SizedBox(
            width: 420,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: notes.length,
              itemBuilder: (_, index) {
                final note = notes[index];
                return ListTile(
                  title: Text(note.topic),
                  subtitle: Text(
                    note.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.of(context).pop(note),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<WorksheetRecord?> _pickWorksheet(
      List<WorksheetRecord> worksheets) async {
    return showDialog<WorksheetRecord>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Share Worksheet'),
          content: SizedBox(
            width: 420,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: worksheets.length,
              itemBuilder: (_, index) {
                final worksheet = worksheets[index];
                return ListTile(
                  title: Text(worksheet.title),
                  subtitle: Text('${worksheet.subject} • ${worksheet.topic}'),
                  onTap: () => Navigator.of(context).pop(worksheet),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final room = _room ?? widget.room;

    return Scaffold(
      appBar: AppBar(
        title: Text(room.name),
        actions: [
          if (_isOwner)
            IconButton(
              tooltip: 'Manage members',
              onPressed: _busy ? null : _manageMembers,
              icon: const Icon(Icons.group_remove_outlined),
            ),
          IconButton(
            tooltip: 'Set Meet link',
            onPressed: _busy ? null : _setMeetLink,
            icon: const Icon(Icons.video_call_outlined),
          ),
          IconButton(
            tooltip: 'Join Meet',
            onPressed: _busy ? null : _joinMeet,
            icon: const Icon(Icons.open_in_new_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${room.memberCount} members')),
                if (room.members.isNotEmpty)
                  ...room.members.take(4).map(
                        (member) => Chip(label: Text(member.name)),
                      ),
                if (room.meetLink.isNotEmpty)
                  const Chip(label: Text('Meet link ready')),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _shareNote,
                  icon: const Icon(Icons.sticky_note_2_outlined),
                  label: const Text('Share Note'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _shareWorksheet,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Share Worksheet'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _busy
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, index) {
                      final message = _messages[index];
                      final action = _messageAction(message);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                              '${message.senderName} • ${message.messageType}'),
                          subtitle: _buildMessageBody(message),
                          trailing: action,
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Write a message...',
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _sendMessage,
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBody(CollabMessage message) {
    if (message.messageType == 'note') {
      final topic = message.payload['topic']?.toString() ?? 'Note';
      final content = message.payload['content']?.toString() ?? '';
      final attachments = _noteAttachmentsFromPayload(message);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            topic,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(_notePreview(content)),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: attachments
                  .map(
                    (attachment) => ActionChip(
                      avatar: Icon(
                        _iconForMimeType(attachment.mimeType),
                        size: 16,
                      ),
                      label: Text(attachment.name),
                      onPressed: () => _openSharedAttachment(message, attachment),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      );
    }

    if (message.messageType == 'worksheet') {
      final title = message.payload['title']?.toString() ?? 'Worksheet';
      final subject = message.payload['subject']?.toString() ?? '';
      final topic = message.payload['topic']?.toString() ?? '';
      final questions =
          (message.payload['questions'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList();
      final preview = questions.take(3).join('\n');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (subject.isNotEmpty || topic.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
                '$subject${subject.isNotEmpty && topic.isNotEmpty ? ' • ' : ''}$topic'),
          ],
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(preview),
          ],
        ],
      );
    }

    if (message.messageType == 'meet') {
      final link = message.payload['meet_link']?.toString() ?? '';
      return Text('Google Meet updated: $link');
    }

    return Text(message.text);
  }
}
