import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AIPage extends StatefulWidget {
  final String username;
  final String sessionKey;

  const AIPage({
    Key? key,
    required this.username,
    required this.sessionKey,
  }) : super(key: key);

  @override
  State<AIPage> createState() => _AIPageState();
}

class _AIPageState extends State<AIPage> {
  final TextEditingController _textController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isTyping = false;
  String _currentResponse = '';
  Timer? _typingTimer;
  int _typingIndex = 0;

  final Color primaryDark = Color(0xFF0A0A0A);
  final Color cardDark = Color(0xFF1A1A1A);
  final Color accentRed = Color(0xFFDC143C);
  final Color userBubbleColor = Color(0xFF8B0000);
  final Color aiBubbleColor = Color(0xFF2A2A2A);

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  void _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('ai_chat_history_${widget.username}');
    
    if (history != null && history.isNotEmpty) {
      setState(() {
        _messages.clear();
        for (var json in history) {
          try {
            final message = jsonDecode(json);
            _messages.add(message);
          } catch (e) {
            print('Error loading message: $e');
          }
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = _messages.map((msg) => jsonEncode(msg)).toList();
    await prefs.setStringList('ai_chat_history_${widget.username}', history);
  }

  void _addMessage(String text, bool isUser) {
    setState(() {
      _messages.add({
        'text': text,
        'isUser': isUser,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startTypingAnimation(String text) {
    setState(() {
      _isTyping = true;
      _currentResponse = '';
      _typingIndex = 0;
    });

    const typingSpeed = 50;

    _typingTimer?.cancel();
    _typingTimer = Timer.periodic(Duration(milliseconds: typingSpeed), (timer) {
      if (_typingIndex < text.length) {
        setState(() {
          _currentResponse = text.substring(0, _typingIndex + 1);
          _typingIndex++;
        });
        _scrollToBottom();
      } else {
        timer.cancel();
        setState(() {
          _isTyping = false;
        });
        _addMessage(text, false);
        _saveChatHistory();
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    _addMessage(text, true);
    _textController.clear();

    try {
      final response = await http.get(
        Uri.parse('https://api.deline.web.id/ai/copilot?text=${Uri.encodeComponent(text)}'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          final aiResponse = data['result'];
          _startTypingAnimation(aiResponse);
        } else {
          _addMessage('Error: ${data['message']}', false);
        }
      } else {
        _addMessage('Error: Failed to connect to AI service. Status code: ${response.statusCode}', false);
      }
    } catch (e) {
      _addMessage('Error: ${e.toString()}', false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearChat() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardDark,
        title: Text(
          'Clear Chat',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to clear all chat history?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _messages.clear();
                _currentResponse = '';
                _isTyping = false;
                _typingTimer?.cancel();
              });
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('ai_chat_history_${widget.username}');
            },
            child: Text(
              'Clear',
              style: TextStyle(color: accentRed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['isUser'];
    final text = message['text'];
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              margin: EdgeInsets.only(right: 8, top: 4),
              child: CircleAvatar(
                backgroundColor: Colors.grey.shade800,
                child: Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                radius: 14,
              ),
            ),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? userBubbleColor : aiBubbleColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isUser ? accentRed.withOpacity(0.3) : Colors.grey.shade700,
                ),
              ),
              child: SelectableText(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser)
            Container(
              margin: EdgeInsets.only(left: 8, top: 4),
              child: CircleAvatar(
                backgroundColor: accentRed,
                child: Text(
                  widget.username[0].toUpperCase(),
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                radius: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(right: 8, top: 4),
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade800,
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 16),
              radius: 14,
            ),
          ),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: aiBubbleColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade700),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: SelectableText(
                      _currentResponse,
                      style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                    ),
                  ),
                  SizedBox(width: 8),
                  AnimatedContainer(
                    duration: Duration(milliseconds: 500),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      appBar: AppBar(
        title: Text(
          'AI Assistant',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: cardDark,
        elevation: 0,
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.white70),
              onPressed: _clearChat,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _messages.length) {
                  return _buildMessageBubble(_messages[index]);
                } else {
                  return _buildTypingBubble();
                }
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardDark,
              border: Border(top: BorderSide(color: Colors.grey.shade800)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: TextStyle(color: Colors.white),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(color: Colors.grey.shade700),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(color: Colors.grey.shade700),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(color: accentRed),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      fillColor: Colors.grey.shade900,
                      filled: true,
                    ),
                    onSubmitted: (text) => _sendMessage(text),
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [accentRed, Color(0xFFFF6B6B)],
                    ),
                  ),
                  child: IconButton(
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.send, color: Colors.white),
                    onPressed: _isLoading
                        ? null
                        : () => _sendMessage(_textController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}