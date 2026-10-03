
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '/auth/firebase_auth/auth_util.dart';
import 'package:google_fonts/google_fonts.dart';

const _kGreen = Color(0xFF1A4731);
const _kAmber = Color(0xFFF5A623);
const _kBgLight = Color(0xFFF4F7F4);
const _kBorder = Color(0xFFD4E8D4);
const _kTextDark = Color(0xFF0D1F12);
const _kTextSecondary = Color(0xFF4D6B57);

class CustomerSupportWidget extends StatefulWidget {
  static String routeName = 'CustomerSupport';
  static String routePath = '/customerSupport';

  const CustomerSupportWidget({super.key});

  @override
  State<CustomerSupportWidget> createState() =>
      _CustomerSupportWidgetState();
}

class _CustomerSupportWidgetState extends State<CustomerSupportWidget> {
  final _msgCtrl = TextEditingController();

  String? _selectedCategory;
  bool _sending = false;

  final _categories = const [
    ('payment', '💳 Payment issue'),
    ('order', '📦 Order problem'),
    ('vendor', '🏪 Vendor issue'),
    ('account', '👤 Account help'),
    ('other', '❓ Something else'),
  ];

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please type a message before sending.'),
        ),
      );
      return;
    }

    final uid = currentUserUid;

    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to contact support.'),
        ),
      );
      return;
    }

    final category = _selectedCategory ?? 'other';

    setState(() => _sending = true);

    try {
      // 1. Save the customer's message to the existing support chat.
      final messageRef = await FirebaseFirestore.instance
          .collection('customerSupportChats')
          .doc(uid)
          .collection('messages')
          .add({
        'senderType': 'customer',
        'senderUid': uid,
        'category': category,
        'text': text,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Clear the input only after the message has been saved.
      _msgCtrl.clear();

      if (mounted) {
        setState(() => _selectedCategory = null);
      }

      // 3. Ask the deployed support agent to process this message.
      //
      // The Firebase function controls which users are allowed to
      // receive automated replies. General customer replies remain
      // disabled in your current backend configuration.
      //
      // The function writes its reply to Firestore. We do NOT add
      // that reply here, which avoids displaying duplicate messages.
      try {
        await FirebaseFunctions.instanceFor(
          region: 'asia-south1',
        ).httpsCallable('supportAgentReply').call({
          'messageId': messageRef.id,
        });
      } on FirebaseFunctionsException catch (e) {
        debugPrint(
          'Support agent error: ${e.code} - ${e.message}',
        );
        // The message is already saved for human support.
      } catch (e) {
        debugPrint('Support agent call failed: $e');
        // The message is already saved for human support.
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent. You can check for replies here.'),
            backgroundColor: _kGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Support message could not be saved: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Could not send your message. '
              'Please check your connection and try again.',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = currentUserUid;

    return Scaffold(
      backgroundColor: _kBgLight,
      appBar: AppBar(
        backgroundColor: _kGreen,
        title: Text(
          'Contact Support',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('customerSupportChats')
                  .doc(uid)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load support messages. '
                        'Please check your connection.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: _kTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }

                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _kGreen,
                    ),
                  );
                }

                final docs = snap.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Having an issue? Pick a category below '
                        'and tell us what happened. '
                        'We will get back to you here.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: _kTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data =
                        docs[i].data() as Map<String, dynamic>;

                    final fromCustomer =
                        data['senderType'] == 'customer';

                    final messageText =
                        data['text']?.toString() ?? '';

                    return Align(
                      alignment: fromCustomer
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color:
                              fromCustomer ? _kGreen : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: fromCustomer
                              ? null
                              : Border.all(color: _kBorder),
                        ),
                        child: Text(
                          messageText,
                          style: GoogleFonts.plusJakartaSans(
                            color: fromCustomer
                                ? Colors.white
                                : _kTextDark,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((category) {
                      return ChoiceChip(
                        label: Text(
                          category.$2,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                          ),
                        ),
                        selected:
                            _selectedCategory == category.$1,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = category.$1;
                          });
                        },
                        selectedColor:
                            _kAmber.withValues(alpha: 0.3),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          decoration: InputDecoration(
                            hintText: 'Describe the issue...',
                            filled: true,
                            fillColor: _kBgLight,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          minLines: 1,
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: _kGreen,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}