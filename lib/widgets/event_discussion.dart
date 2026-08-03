import 'dart:async';
import '../theme.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';
import '../models/event_message.dart';

class EventDiscussion extends StatefulWidget {
  final String eventId;
  final String? communityId;
  final bool discussionEnabled;
  final bool discussionRestricted;
  final String currentUserId;
  final bool isAdmin;

  const EventDiscussion({
    super.key,
    required this.eventId,
    this.communityId,
    required this.discussionEnabled,
    required this.discussionRestricted,
    required this.currentUserId,
    required this.isAdmin,
  });

  @override
  State<EventDiscussion> createState() => _EventDiscussionState();
}

class _EventDiscussionState extends State<EventDiscussion> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<EventMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _isBanned = false;
  bool _isRemoved = false;
  String? _error;
  RealtimeChannel? _channel;
  String? _editingId;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final messagesRes = await supabase
          .from('event_messages')
          .select('*, profiles:user_id(first_name, last_name, avatar_url)')
          .eq('event_id', widget.eventId)
          .order('created_at');
      if (!mounted) return;
      final messages = (messagesRes as List)
          .map((m) => EventMessage.fromMap(m as Map<String, dynamic>))
          .toList();
      bool banned = false;
      try {
        final banRes = await supabase
            .from('event_restricted_users')
            .select('id')
            .eq('event_id', widget.eventId)
            .eq('user_id', widget.currentUserId)
            .maybeSingle();
        banned = banRes != null;
      } catch (_) {}
      bool removed = false;
      final communityId = widget.communityId;
      if (communityId != null) {
        try {
          final memberRes = await supabase
              .from('community_members')
              .select('community_id')
              .eq('community_id', communityId)
              .eq('user_id', widget.currentUserId)
              .maybeSingle();
          removed = memberRes == null;
        } catch (_) {}
      }
      setState(() {
        _messages = messages;
        _isBanned = banned;
        _isRemoved = removed;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _subscribe() {
    _channel = supabase.channel('event-discussion-${widget.eventId}');
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'event_messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'event_id',
        value: widget.eventId,
      ),
      callback: (payload) {
        if (!mounted) return;
        final msg = EventMessage.fromMap(
            payload.newRecord);
        setState(() => _messages.add(msg));
        _scrollToBottom();
      },
    );
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'event_restricted_users',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'event_id',
        value: widget.eventId,
      ),
      callback: (payload) {
        if (!mounted) return;
        final userId =
            (payload.newRecord['user_id'] ?? payload.oldRecord['user_id']) as String?;
        if (userId != widget.currentUserId) return;
        final isBanned =
            payload.eventType == PostgresChangeEvent.insert;
        setState(() => _isBanned = isBanned);
      },
    );
    final communityId = widget.communityId;
    if (communityId != null) {
      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'community_members',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'community_id',
          value: communityId,
        ),
        callback: (payload) {
          if (!mounted) return;
          final userId = payload.oldRecord['user_id'] as String?;
          if (userId != widget.currentUserId) return;
          setState(() => _isRemoved = true);
        },
      );
    }
    _channel!.subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await supabase.from('event_messages').insert({
        'event_id': widget.eventId,
        'user_id': widget.currentUserId,
        'content': text,
      });
      _controller.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red[700],
        ),
      );
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _edit(EventMessage msg) async {
    _controller.text = msg.content;
    setState(() => _editingId = msg.id);
    _scrollToBottom();
  }

  Future<void> _saveEdit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _editingId == null) return;
    try {
      await supabase
          .from('event_messages')
          .update({'content': text})
          .eq('id', _editingId!);
      final idx = _messages.indexWhere((m) => m.id == _editingId);
      if (idx != -1) {
        setState(() {
          _messages[idx].content = text;
          _messages[idx].updatedAt = DateTime.now();
        });
      }
      _controller.clear();
      setState(() => _editingId = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red[700]),
      );
    }
  }

  Future<void> _delete(String messageId) async {
    try {
      await supabase.from('event_messages').delete().eq('id', messageId);
      setState(() => _messages.removeWhere((m) => m.id == messageId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red[700]),
      );
    }
  }

  void _showActions(EventMessage msg) {
    final isOwn = msg.userId == widget.currentUserId;
    final canDelete = isOwn || widget.isAdmin;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwn)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(ctx);
                  _edit(msg);
                },
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _delete(msg.id);
                },
              ),
            if (!isOwn && widget.isAdmin)
              ListTile(
                leading: const Icon(Icons.block, color: Colors.orange),
                title: const Text('Restrict user',
                    style: TextStyle(color: Colors.orange)),
                onTap: () {
                  Navigator.pop(ctx);
                  _restrictUser(msg.userId);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restrictUser(String userId) async {
    try {
      await supabase.from('event_restricted_users').insert({
        'event_id': widget.eventId,
        'user_id': userId,
        'created_by': widget.currentUserId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User restricted from posting.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red[700]),
      );
    }
  }

  bool get _canPost =>
      widget.discussionEnabled &&
      !_isBanned &&
      !_isRemoved &&
      (!widget.discussionRestricted || widget.isAdmin);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 32, color: context.cluvoTextSecondary),
              const SizedBox(height: 8),
              Text('Failed to load discussion.',
                  style: TextStyle(color: context.cluvoTextSecondary)),
              const SizedBox(height: 4),
              Text(_error!,
                  style: TextStyle(color: context.cluvoTextSecondary, fontSize: 11),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 48, color: context.cluvoTextSecondary),
                      const SizedBox(height: 12),
                      Text('No messages yet. Start the conversation!',
                          style: TextStyle(color: context.cluvoTextSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isOwn = msg.userId == widget.currentUserId;
                    return _buildMessageBubble(msg, isOwn);
                  },
                ),
        ),
        if (!widget.discussionEnabled)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: context.cluvoChipFill,
              border: Border(top: BorderSide(color: context.cluvoBorder)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: context.cluvoTextSecondary),
                const SizedBox(width: 8),
                Text('Discussion has not been enabled for this event.',
                    style: TextStyle(color: context.cluvoTextSecondary, fontSize: 13)),
              ],
            ),
          )
        else if (_isBanned)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              border: Border(top: BorderSide(color: Colors.orange[200]!)),
            ),
            child: Row(
              children: [
                Icon(Icons.block, size: 16, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text('You have been restricted from posting.',
                    style: TextStyle(color: Colors.orange[800], fontSize: 13)),
              ],
            ),
          )
        else if (_isRemoved)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: context.cluvoChipFill,
              border: Border(top: BorderSide(color: context.cluvoBorder)),
            ),
            child: Row(
              children: [
                Icon(Icons.person_off_outlined, size: 16, color: context.cluvoTextSecondary),
                const SizedBox(width: 8),
                Text('You are no longer a member of this community.',
                    style: TextStyle(color: context.cluvoTextSecondary, fontSize: 13)),
              ],
            ),
          )
        else if (!_canPost && widget.discussionRestricted)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: context.cluvoChipFill,
              border: Border(top: BorderSide(color: context.cluvoBorder)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: context.cluvoTextSecondary),
                const SizedBox(width: 8),
                Text('Only admins can post in this discussion.',
                    style: TextStyle(color: context.cluvoTextSecondary, fontSize: 13)),
              ],
            ),
          )
        else
          _buildInputBar(),
      ],
    );
  }

  Widget _buildMessageBubble(EventMessage msg, bool isOwn) {
    return GestureDetector(
      onLongPress: () => _showActions(msg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          textDirection: isOwn ? TextDirection.rtl : TextDirection.ltr,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFC2185B).withValues(alpha: 0.15),
              backgroundImage: msg.senderAvatarUrl != null
                  ? CachedNetworkImageProvider(msg.senderAvatarUrl!)
                  : null,
              child: msg.senderAvatarUrl == null
                  ? Text(
                      (msg.senderName ?? 'U')[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFC2185B),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: isOwn
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.senderName ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: context.cluvoTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isOwn
                          ? const Color(0xFFC2185B).withValues(alpha: 0.1)
                          : context.cluvoChipFill,
                      borderRadius: BorderRadius.circular(12).copyWith(
                        bottomLeft:
                            isOwn ? const Radius.circular(12) : Radius.zero,
                        bottomRight:
                            isOwn ? Radius.zero : const Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: isOwn
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.content,
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (msg.updatedAt
                                .difference(msg.createdAt)
                                .inSeconds >
                            5) ...[
                          const SizedBox(height: 2),
                          Text(
                            'edited',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.cluvoTextSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(msg.createdAt),
                    style: TextStyle(fontSize: 10, color: context.cluvoTextSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: context.cluvoSurface,
        border: Border(top: BorderSide(color: context.cluvoBorder)),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _editingId != null ? 'Edit message...' : 'Type a message...',
                hintStyle: TextStyle(color: context.cluvoTextSecondary, fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: context.cluvoChipFill,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _editingId != null ? _saveEdit() : _send(),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _editingId != null ? _saveEdit : _send,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFC2185B),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _editingId != null ? Icons.check : Icons.send,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
