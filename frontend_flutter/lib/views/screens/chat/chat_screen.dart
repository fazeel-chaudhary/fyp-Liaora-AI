import 'package:flutter/material.dart';
import 'package:frontend_flutter/providers/auth/auth_provider.dart';
import 'package:frontend_flutter/providers/chat/chat_provider.dart';
import 'package:frontend_flutter/models/message_model.dart';
import 'package:frontend_flutter/views/reusables/message_bubble.dart';
import 'package:provider/provider.dart';
import 'package:frontend_flutter/utils/error_handler/snackbar.dart';
import 'package:frontend_flutter/utils/media-query/size_config.dart';
import 'package:frontend_flutter/views/reusables/icon_box.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String botName;
  final Color botColor;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.botName,
    required this.botColor,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isComposing = false;

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      setState(() {
        _isComposing = _controller.text.trim().isNotEmpty;
      });
    });

    // ✅ Load messages after first frame to avoid build-time rebuilds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.loadMessages(context, widget.userId, widget.botName);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    // ✅ Avoid build-phase setState errors
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (token == null || token.isEmpty) {
        SnackbarHelper.show(context, "Session expired — please sign in again.");
        return;
      }
      await chatProvider.sendMessage(
        context,
        widget.userId,
        widget.botName,
        text,
        token,
      );
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.botColor.withOpacity(0.05),
              theme.scaffoldBackgroundColor,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Enhanced Custom App Bar with gradient
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor.withOpacity(0.95),
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.onSurface.withOpacity(0.06),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconBox(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    // Bot Avatar
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.botColor,
                            widget.botColor.withOpacity(0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.botColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.botName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.botName,
                            style: TextStyle(
                              fontSize: SizeConfig.height * 0.02,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Online",
                                style: TextStyle(
                                  fontSize: SizeConfig.height * 0.014,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconBox(
                      icon: Icons.more_vert_rounded,
                      onTap: () {
                        // Add menu functionality if needed
                      },
                    ),
                  ],
                ),
              ),

              // Chat List with enhanced design
              Expanded(
                child: chatProvider.isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.botColor,
                              ),
                            ),
                            SizedBox(height: SizeConfig.height * 0.02),
                            Text(
                              "Loading messages...",
                              style: TextStyle(
                                fontSize: SizeConfig.height * 0.016,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : chatProvider.messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: widget.botColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: SizeConfig.height * 0.06,
                                color: widget.botColor,
                              ),
                            ),
                            SizedBox(height: SizeConfig.height * 0.03),
                            Text(
                              "Start a conversation",
                              style: TextStyle(
                                fontSize: SizeConfig.height * 0.022,
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: SizeConfig.height * 0.01),
                            Text(
                              "Send a message to ${widget.botName}",
                              style: TextStyle(
                                fontSize: SizeConfig.height * 0.016,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        itemCount: chatProvider.messages.length,
                        itemBuilder: (context, index) {
                          final Message msg = chatProvider.messages[index];
                          final bool isUser = msg.sender == "user";
                          final bool showAvatar =
                              index == 0 ||
                              chatProvider.messages[index - 1].sender !=
                                  msg.sender;

                          return MessageBubble(
                            message: msg,
                            isUser: isUser,
                            botColor: widget.botColor,
                            showAvatar: showAvatar,
                            botName: widget.botName,
                          );
                        },
                      ),
              ),

              // Enhanced Message Input with animations
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 16,
                ),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _focusNode.hasFocus
                                ? widget.botColor.withOpacity(0.3)
                                : theme.colorScheme.onSurface.withOpacity(0.1),
                            width: 1.5,
                          ),
                          boxShadow: _focusNode.hasFocus
                              ? [
                                  BoxShadow(
                                    color: widget.botColor.withOpacity(0.1),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : [],
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          style: TextStyle(
                            fontSize: SizeConfig.height * 0.018,
                            color: theme.colorScheme.onSurface,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            hintText: "Type a message...",
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.4,
                              ),
                              fontSize: SizeConfig.height * 0.018,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedScale(
                      scale: _isComposing ? 1.0 : 0.85,
                      duration: const Duration(milliseconds: 200),
                      child: GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isComposing
                                  ? [
                                      widget.botColor,
                                      widget.botColor.withOpacity(0.8),
                                    ]
                                  : [
                                      theme.colorScheme.onSurface.withOpacity(
                                        0.2,
                                      ),
                                      theme.colorScheme.onSurface.withOpacity(
                                        0.15,
                                      ),
                                    ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: _isComposing
                                ? [
                                    BoxShadow(
                                      color: widget.botColor.withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Icon(
                            Icons.send_rounded,
                            color: _isComposing
                                ? Colors.white
                                : theme.colorScheme.onSurface.withOpacity(0.4),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
