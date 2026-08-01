import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/shared_widgets/app_button.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});
  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _submitted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Contact / Support', style: AppTextStyles.headlineSmall(cs.onSurface)),
      ),
      body: _submitted
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✅', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text('Message Sent!', style: AppTextStyles.headlineSmall(cs.onSurface)),
                const SizedBox(height: 8),
                Text('We\'ll get back to you within 24 hours.',
                  style: AppTextStyles.bodyMedium(cs.onSurfaceVariant)),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Get in Touch', style: AppTextStyles.headlineMedium(cs.onSurface)),
              const SizedBox(height: 8),
              Text('Have a question or feedback? We\'d love to hear from you.',
                style: AppTextStyles.bodyMedium(cs.onSurfaceVariant)),
              const SizedBox(height: 24),
              // FAQs
              Text('Common Questions', style: AppTextStyles.titleLarge(cs.onSurface)),
              const SizedBox(height: 12),
              ..._faqs.map((faq) => ExpansionTile(
                title: Text(faq.$1, style: AppTextStyles.bodyMedium(cs.onSurface)
                  .copyWith(fontWeight: FontWeight.w600)),
                children: [Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(faq.$2, style: AppTextStyles.bodyMedium(cs.onSurfaceVariant)),
                )],
              )),
              const SizedBox(height: 24),
              // Contact form
              Text('Send a Message', style: AppTextStyles.titleLarge(cs.onSurface)),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _subjectCtrl,
                      decoration: const InputDecoration(hintText: 'Subject'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _messageCtrl,
                      maxLines: 5,
                      decoration: const InputDecoration(hintText: 'Your message...'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    AppPrimaryButton(label: 'Send Message', onPressed: _submit,
                      icon: Icons.send_rounded),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}

const _faqs = [
  ('How do I Go Live?', 'Tap the Go Live button from Profile or the bottom navigation. You can stream from your own device camera to viewers within the app.'),
  ('Is my data saved?', 'CRIXORA currently runs locally with no account required. Your profile and preferences are stored on your device.'),
  ('How often do scores update?', 'Scores are updated in real-time from live match data sources.'),
  ('Can I watch other people\'s streams?', 'Yes! Streams from other broadcasters who are streaming their own camera feeds (club matches, academy games, etc.) appear in the Live Viewer section.'),
];
