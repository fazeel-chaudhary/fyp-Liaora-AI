import 'package:flutter/material.dart';
import 'package:frontend_flutter/providers/auth/auth_provider.dart';
import 'package:frontend_flutter/providers/chat/chat_provider.dart';
import 'package:frontend_flutter/providers/localization/localization_provider.dart';
import 'package:frontend_flutter/models/message_model.dart';
import 'package:frontend_flutter/utils/navigation/navigator.dart';
import 'package:frontend_flutter/views/reusables/message_bubble.dart';
import 'package:frontend_flutter/views/screens/features/ai_features_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:provider/provider.dart';
import 'package:frontend_flutter/utils/error_handler/snackbar.dart';
import 'package:frontend_flutter/utils/media-query/size_config.dart';
import 'package:frontend_flutter/views/reusables/icon_box.dart';
import 'dart:async';
import 'package:frontend_flutter/services/chat_services.dart';

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
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isComposing = false;
  bool _isListening = false;
  bool _voiceReady = false;
  bool _autoSpeakEnabled = false;
  bool _isCallMode = false;
  bool _isBotSpeaking = false;
  bool _isSendingVoiceTurn = false;
  String _latestTranscript = '';
  Timer? _speechCommitTimer;
  String _resolvedCallLocale = 'en_US';
  bool _hasUrduLocale = false;
  String _lastHeardText = '';

  @override
  void initState() {
    super.initState();
    _initializeVoice();

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
    _speechCommitTimer?.cancel();
    _speechToText.stop();
    _flutterTts.stop();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeVoice() async {
    _voiceReady = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() => _isListening = false);
          }
          if (_isCallMode && !_isBotSpeaking && !_isSendingVoiceTurn) {
            Future.delayed(const Duration(milliseconds: 350), () {
              if (mounted && _isCallMode && !_isListening && !_isBotSpeaking) {
                _toggleListening();
              }
            });
          }
        }
      },
    );
    await _resolveSpeechLocale();
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    _flutterTts.setCompletionHandler(() {
      _isBotSpeaking = false;
      if (_isCallMode && mounted && !_isListening) {
        _toggleListening();
      }
    });
    _flutterTts.setErrorHandler((_) {
      _isBotSpeaking = false;
    });
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token == null || token.isEmpty) {
      if (mounted) {
        SnackbarHelper.show(context, "Session expired — please sign in again.");
      }
      return;
    }

    if (_isCallMode) {
      final res = await ChatService.sendLiveMessage(
        widget.userId,
        widget.botName,
        trimmed,
        token,
      );
      final reply = res['bot_response'];
      if (reply is! String || reply.trim().isEmpty) {
        if (mounted) {
          SnackbarHelper.show(context, "Call response failed");
        }
        return;
      }
      _isBotSpeaking = true;
      await _setTtsLanguageForText(reply);
      await _flutterTts.speak(reply);
      return;
    }

    await chatProvider.sendMessage(
      context,
      widget.userId,
      widget.botName,
      trimmed,
      token,
    );
    if ((_autoSpeakEnabled || _isCallMode) && chatProvider.messages.isNotEmpty) {
      final latest = chatProvider.messages.last;
      if (latest.sender == 'bot') {
        _isBotSpeaking = true;
        await _setTtsLanguageForText(latest.content);
        await _flutterTts.speak(latest.content);
      }
    }
    _scrollToBottom();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _sendText(text);
  }

  Future<void> _toggleListening() async {
    if (!_voiceReady || _isBotSpeaking) return;
    if (_isListening) {
      _speechCommitTimer?.cancel();
      await _speechToText.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
      return;
    }

    setState(() => _isListening = true);
    await _speechToText.listen(
      onResult: (result) {
        final words = result.recognizedWords.trim();
        if (_isCallMode) {
          if (words.isNotEmpty) {
            _latestTranscript = words;
            if (mounted) {
              setState(() => _lastHeardText = words);
            }
            if (_isLikelyUrdu(words) && _hasUrduLocale) {
              _resolvedCallLocale = 'ur_PK';
            } else {
              _resolvedCallLocale = 'en_US';
            }
            _scheduleVoiceCommit();
          }
          if (result.finalResult && words.isNotEmpty) {
            _commitVoiceTurn();
          }
          return;
        }

        setState(() {
          _controller.text = words;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      },
      listenOptions: SpeechListenOptions(
        listenMode: _isCallMode ? ListenMode.dictation : ListenMode.confirmation,
      ),
      localeId: _isCallMode ? _resolvedCallLocale : null,
    );
  }

  void _scheduleVoiceCommit() {
    _speechCommitTimer?.cancel();
    _speechCommitTimer = Timer(const Duration(milliseconds: 1200), () {
      _commitVoiceTurn();
    });
  }

  Future<void> _commitVoiceTurn() async {
    if (!_isCallMode || _isSendingVoiceTurn) return;
    final text = _latestTranscript.trim();
    if (text.isEmpty || !_isMeaningfulSpeech(text)) return;

    _isSendingVoiceTurn = true;
    _speechCommitTimer?.cancel();
    _latestTranscript = '';
    await _speechToText.stop();
    if (mounted) {
      setState(() => _isListening = false);
    }
    try {
      await _sendText(text);
    } finally {
      _isSendingVoiceTurn = false;
    }
  }

  Future<void> _startCallFlow() async {
    if (_isCallMode && _isListening) return;
    if (!mounted) return;
    final shouldConnect = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CallingDialog(botName: widget.botName),
    );
    if (shouldConnect != true) return;

    if (mounted) {
      setState(() {
        _isCallMode = true;
        _autoSpeakEnabled = true;
      });
    }
    await _toggleListening();
  }

  bool _isLikelyUrdu(String text) {
    final urduScript = RegExp(r'[\u0600-\u06FF]');
    if (urduScript.hasMatch(text)) return true;
    final lower = text.toLowerCase();
    const romanUrduHints = [
      'kya',
      'hain',
      'hai',
      'mein',
      'mera',
      'meri',
      'tum',
      'aap',
      'nahi',
      'kyun',
      'bol',
      'urdu',
    ];
    return romanUrduHints.any(lower.contains);
  }

  bool _isMeaningfulSpeech(String text) {
    final hasWordLike = RegExp(r'[A-Za-z0-9\u0600-\u06FF]').hasMatch(text);
    final punctuationOnly = RegExp(
      '^[\\s\\.,!?;:\\-\'"(){}\\[\\]/\\\\|@#\\\$%\\^&\\*+=_`~]+\$',
    ).hasMatch(text);
    return hasWordLike && !punctuationOnly && text.trim().length >= 2;
  }

  Future<void> _resolveSpeechLocale() async {
    try {
      final locales = await _speechToText.locales();
      final ids = locales.map((e) => e.localeId.toLowerCase()).toList();
      if (ids.contains('ur_pk')) {
        _hasUrduLocale = true;
        _resolvedCallLocale = 'ur_PK';
      } else if (ids.contains('en_us')) {
        _resolvedCallLocale = 'en_US';
      }
    } catch (_) {
      _resolvedCallLocale = 'en_US';
    }
  }

  Future<void> _setTtsLanguageForText(String text) async {
    final target = _isLikelyUrdu(text) ? 'ur-PK' : 'en-US';
    try {
      await _flutterTts.setLanguage(target);
    } catch (_) {
      await _flutterTts.setLanguage('en-US');
    }
  }

  void _openChatMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        bool localCallMode = _isCallMode;
        bool localAutoSpeak = _autoSpeakEnabled;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.auto_awesome_rounded),
                      title: const Text('Open AI Feature Lab'),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(
                          this.context,
                        ).push(elegantRoute(const AIFeaturesScreen()));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.call_rounded),
                      title: const Text('Start call now'),
                      subtitle: const Text('Begin listening immediately'),
                      onTap: () {
                        setModalState(() {
                          localCallMode = true;
                          localAutoSpeak = true;
                        });
                        setState(() {
                          _isCallMode = true;
                          _autoSpeakEnabled = true;
                        });
                        Navigator.of(context).pop();
                        _toggleListening();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.call_end_rounded),
                      title: const Text('End call'),
                      onTap: () async {
                        if (_isListening) {
                          _speechCommitTimer?.cancel();
                          _latestTranscript = '';
                          await _speechToText.stop();
                        }
                        if (_isBotSpeaking) {
                          await _flutterTts.stop();
                          _isBotSpeaking = false;
                        }
                        if (mounted) {
                          setState(() {
                            _isListening = false;
                            _isCallMode = false;
                            _autoSpeakEnabled = false;
                          });
                        }
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    SwitchListTile(
                      value: localCallMode,
                      onChanged: (value) {
                        setModalState(() {
                          localCallMode = value;
                          localAutoSpeak = value;
                        });
                        setState(() {
                          _isCallMode = value;
                          _autoSpeakEnabled = value;
                        });
                        if (value) {
                          _toggleListening();
                        } else if (_isListening) {
                          _speechCommitTimer?.cancel();
                          _latestTranscript = '';
                          _speechToText.stop();
                        }
                      },
                      title: const Text('Call mode (voice in/out)'),
                      subtitle: const Text(
                        'Speak on mic, auto-send, and bot speaks replies',
                      ),
                      secondary: const Icon(Icons.call_rounded),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      value: localAutoSpeak,
                      onChanged: (value) {
                        setModalState(() {
                          localAutoSpeak = value;
                          if (!value) {
                            localCallMode = false;
                          }
                        });
                        setState(() {
                          _autoSpeakEnabled = value;
                          if (!value) {
                            _isCallMode = false;
                          }
                        });
                      },
                      title: const Text('Voice mode (bot speaks replies)'),
                      subtitle: const Text('Enable only when you want call-like chat'),
                      secondary: const Icon(Icons.record_voice_over_rounded),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
    final localizationProvider = Provider.of<LocalizationProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.botColor.withValues(alpha: 0.05),
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
                  color: theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
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
                            widget.botColor.withValues(alpha: 0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.botColor.withValues(alpha: 0.3),
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
                                      color: Colors.green.withValues(alpha: 0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                localizationProvider.t('online'),
                                style: TextStyle(
                                  fontSize: SizeConfig.height * 0.014,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconBox(
                      icon: Icons.call_rounded,
                      onTap: _startCallFlow,
                    ),
                    const SizedBox(width: 8),
                    IconBox(
                      icon: Icons.more_vert_rounded,
                      onTap: _openChatMenu,
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    if (_isCallMode)
                      const Chip(
                        label: Text('Call mode ON'),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (_isListening)
                      const Chip(
                        label: Text('Listening...'),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (_isBotSpeaking)
                      const Chip(
                        label: Text('Bot speaking...'),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (_isCallMode && _lastHeardText.isNotEmpty)
                      Chip(
                        label: Text('Heard: $_lastHeardText'),
                        visualDensity: VisualDensity.compact,
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
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
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
                                color: widget.botColor.withValues(alpha: 0.1),
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
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
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
                          final bool isUser =
                              msg.sender == "user" ||
                              msg.sender == widget.userId ||
                              msg.sender.startsWith("user::");
                          final Message? previous = index > 0
                              ? chatProvider.messages[index - 1]
                              : null;
                          final bool previousIsUser = previous != null &&
                              (previous.sender == "user" ||
                                  previous.sender == widget.userId ||
                                  previous.sender.startsWith("user::"));
                          final bool showAvatar =
                              index == 0 || previousIsUser != isUser;

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
                      color: Colors.black.withValues(alpha: 0.08),
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
                                ? widget.botColor.withValues(alpha: 0.3)
                                : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                            width: 1.5,
                          ),
                          boxShadow: _focusNode.hasFocus
                              ? [
                                  BoxShadow(
                                    color: widget.botColor.withValues(alpha: 0.1),
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
                            hintText: localizationProvider.t('chat_placeholder'),
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
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
                    GestureDetector(
                      onTap: _toggleListening,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _isListening
                              ? Colors.redAccent
                              : _isCallMode
                                  ? widget.botColor.withValues(alpha: 0.18)
                                  : theme.colorScheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Icon(
                          _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                          color: _isListening
                              ? Colors.white
                              : _isCallMode
                                  ? widget.botColor
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                                      widget.botColor.withValues(alpha: 0.8),
                                    ]
                                  : [
                                      theme.colorScheme.onSurface.withValues(
                                        alpha: 0.2,
                                      ),
                                      theme.colorScheme.onSurface.withValues(
                                        alpha: 0.15,
                                      ),
                                    ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: _isComposing
                                ? [
                                    BoxShadow(
                                      color: widget.botColor.withValues(alpha: 0.4),
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
                                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
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

class _CallingDialog extends StatefulWidget {
  const _CallingDialog({required this.botName});

  final String botName;

  @override
  State<_CallingDialog> createState() => _CallingDialogState();
}

class _CallingDialogState extends State<_CallingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _pulse,
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.call_rounded,
                  color: theme.colorScheme.primary,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.botName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ringing... connecting voice call',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.call_end_rounded),
                  label: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
