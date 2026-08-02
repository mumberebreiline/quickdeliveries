import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

/// A real feedback form — star rating plus an optional comment, saved
/// straight to Firestore. Every visitor is already signed in anonymously
/// by the time they reach any screen (see main.dart), so this never
/// needs to ask for an account first.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a star rating first')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    var user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await AuthService().ensureSignedIn();
      user = FirebaseAuth.instance.currentUser;
    }

    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'userId': user?.uid,
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Thanks for the feedback!')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send feedback: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'How was your experience?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNumber = index + 1;
                return IconButton(
                  iconSize: 36,
                  onPressed: () => setState(() => _rating = starNumber),
                  icon: Icon(
                    starNumber <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  tooltip: '$starNumber star${starNumber == 1 ? '' : 's'}',
                );
              }),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _commentController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Tell us more (optional)',
                hintText: 'What went well, or what could be better?',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit Feedback'),
            ),
          ],
        ),
      ),
    );
  }
}
