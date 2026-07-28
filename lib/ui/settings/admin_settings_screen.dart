import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:sportyapp/data/models/admin_settings.dart';
import 'package:sportyapp/data/providers/admin_settings_provider.dart';
import 'package:sportyapp/core/utils/stream_url_validator.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/constants/app_constants.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final _apiUrlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _apiHostCtrl = TextEditingController();
  final _videoUrlCtrl = TextEditingController();
  final _videoNameCtrl = TextEditingController();

  String? _apiStatusMsg;
  bool _apiConnected = false;
  bool _apiTesting = false;
  bool _apiExpanded = false;
  bool _videoExpanded = false;

  @override
  void dispose() {
    _apiUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _apiHostCtrl.dispose();
    _videoUrlCtrl.dispose();
    _videoNameCtrl.dispose();
    super.dispose();
  }

  void _loadIntoControllers(AdminSettings s) {
    _apiUrlCtrl.text = s.apiBaseUrl;
    _apiKeyCtrl.text = s.apiKey;
    _apiHostCtrl.text = s.apiHost;
    _videoUrlCtrl.text = s.videoUrl;
    _videoNameCtrl.text = s.videoMatchName;
  }

  @override
  Widget build(BuildContext context) {
    final asyncSettings = ref.watch(adminSettingsProvider);
    final cs = Theme.of(context).colorScheme;

    asyncSettings.whenOrNull(data: _loadIntoControllers);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Settings')),
      body: asyncSettings.when(
        data: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildUnifiedCricketApiCard(cs, settings),
            const SizedBox(height: 16),
            _buildVideoCard(cs, settings),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildUnifiedCricketApiCard(ColorScheme cs, AdminSettings settings) {
    return Card(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        side: BorderSide(color: AppColors.pitchGreenLight.withOpacity(0.4), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header / Manage Multi-API Row
          InkWell(
            onTap: () => context.push('/cricket-api-settings'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.pitchGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.api_rounded, color: AppColors.pitchGreenLight, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cricket API Settings',
                            style: AppTextStyles.titleMedium(cs.onBackground)
                                .copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          'Manage all connected live APIs, REST endpoints & M3U channels',
                          style: AppTextStyles.bodySmall(cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.pitchGreenLight),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Collapsible Quick API Config
          InkWell(
            onTap: () => setState(() => _apiExpanded = !_apiExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Quick Endpoint Configuration',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(_apiExpanded ? Icons.expand_less : Icons.expand_more, color: cs.onSurfaceVariant, size: 20),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _textField(cs, 'API Base URL', _apiUrlCtrl, hint: 'https://api.cricapi.com/v1'),
                  const SizedBox(height: 12),
                  _textField(cs, 'API Key (optional)', _apiKeyCtrl, obscure: true),
                  const SizedBox(height: 12),
                  _textField(cs, 'API Host (optional)', _apiHostCtrl, hint: 'cricapi.com'),
                  const SizedBox(height: 16),
                  if (_apiStatusMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(
                            _apiConnected ? Icons.check_circle : Icons.error,
                            color: _apiConnected ? Colors.green : Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _apiStatusMsg!,
                              style: AppTextStyles.bodyMedium(
                                _apiConnected ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_apiTesting)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Testing connection...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.pitchGreenLight,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () => _saveApi(settings),
                            child: const Text('Save API'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            onPressed: _apiTesting ? null : _testApi,
                            child: Text(_apiTesting ? 'Testing...' : 'Test API'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _iconBtn(Icons.delete_outline, Colors.red, _clearApi),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState: _apiExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(ColorScheme cs, AdminSettings settings) {
    return Card(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        side: BorderSide(color: cs.outline.withOpacity(0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _videoExpanded = !_videoExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.videocam_rounded, color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Live Match Video Source',
                      style: AppTextStyles.titleMedium(cs.onBackground)),
                  ),
                  Icon(_videoExpanded ? Icons.expand_less : Icons.expand_more, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _textField(cs, 'Match Name', _videoNameCtrl, hint: 'India vs Pakistan'),
                  const SizedBox(height: 12),
                  _textField(cs, 'Video URL', _videoUrlCtrl, hint: 'https://example.com/stream.m3u8'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _actionBtn('Save', cs.primary, () => _saveVideo(settings)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _actionBtn('Preview', Colors.orange, _previewVideo),
                      ),
                      const SizedBox(width: 8),
                      _iconBtn(Icons.delete_outline, Colors.red, _clearVideo),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.pitchGreenLight,
                        side: const BorderSide(color: AppColors.pitchGreenLight),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.science_outlined, size: 18),
                      label: const Text('Test Streams (Sample URLs)'),
                      onPressed: () => context.push('/test-video'),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _videoExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _textField(ColorScheme cs, String label, TextEditingController ctrl, {bool obscure = false, String? hint}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppTextStyles.bodySmall(cs.onSurfaceVariant),
        hintStyle: AppTextStyles.bodySmall(cs.onSurfaceVariant.withOpacity(0.5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      style: AppTextStyles.bodyMedium(cs.onBackground),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 40, width: 40,
      child: IconButton(
        style: IconButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: Icon(icon, color: color, size: 20),
        onPressed: onTap,
      ),
    );
  }

  Future<void> _saveApi(AdminSettings current) async {
    final baseUrl = _apiUrlCtrl.text.trim();
    final apiKey = _apiKeyCtrl.text.trim();

    if (baseUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Base URL is required'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final updated = current.copyWith(
      apiBaseUrl: baseUrl,
      apiKey: apiKey,
      apiHost: _apiHostCtrl.text.trim(),
      updatedAt: DateTime.now(),
    );
    await ref.read(adminSettingsProvider.notifier).save(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API settings saved')),
      );
    }
  }

  Future<void> _testApi() async {
    final baseUrl = _apiUrlCtrl.text.trim();
    final apiKey = _apiKeyCtrl.text.trim();
    final apiHost = _apiHostCtrl.text.trim();

    if (baseUrl.isEmpty) {
      setState(() {
        _apiConnected = false;
        _apiStatusMsg = 'Base URL is required';
      });
      return;
    }

    setState(() {
      _apiTesting = true;
      _apiStatusMsg = null;
    });

    final endpoint = baseUrl.endsWith('/')
        ? '${baseUrl}mcenter/v1/40381/hscard'
        : '$baseUrl/mcenter/v1/40381/hscard';

    try {
      final response = await http
          .get(
            Uri.parse(endpoint),
            headers: {
              'X-RapidAPI-Key': apiKey,
              if (apiHost.isNotEmpty) 'X-RapidAPI-Host': apiHost,
            },
          )
          .timeout(const Duration(seconds: 10));

      if (mounted) {
        switch (response.statusCode) {
          case 200:
            setState(() {
              _apiConnected = true;
              _apiStatusMsg = 'API Connected Successfully';
            });
            final current = ref.read(adminSettingsProvider).valueOrNull ?? const AdminSettings();
            await ref.read(adminSettingsProvider.notifier).save(current.copyWith(
              apiBaseUrl: baseUrl,
              apiKey: apiKey,
              apiHost: apiHost,
              updatedAt: DateTime.now(),
            ));
          case 401:
            setState(() {
              _apiConnected = false;
              _apiStatusMsg = 'Invalid API Key';
            });
          case 403:
            setState(() {
              _apiConnected = false;
              _apiStatusMsg = 'Subscription Required or Access Denied';
            });
          case 404:
            setState(() {
              _apiConnected = false;
              _apiStatusMsg = 'Invalid Endpoint';
            });
          default:
            setState(() {
              _apiConnected = false;
              _apiStatusMsg = 'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}';
            });
        }
      }
    } on SocketException {
      if (mounted) {
        setState(() {
          _apiConnected = false;
          _apiStatusMsg = 'No Internet Connection';
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _apiConnected = false;
          _apiStatusMsg = 'Connection timed out after 10 seconds';
        });
      }
    } on http.ClientException catch (e) {
      if (mounted) {
        setState(() {
          _apiConnected = false;
          _apiStatusMsg = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _apiConnected = false;
          _apiStatusMsg = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _apiTesting = false);
    }
  }

  Future<void> _clearApi() async {
    final current = ref.read(adminSettingsProvider).valueOrNull ?? const AdminSettings();
    final cleared = current.copyWith(apiBaseUrl: '', apiKey: '', apiHost: '');
    await ref.read(adminSettingsProvider.notifier).save(cleared);
    _apiUrlCtrl.clear();
    _apiKeyCtrl.clear();
    _apiHostCtrl.clear();
    setState(() {
      _apiStatusMsg = null;
      _apiConnected = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API settings cleared')),
      );
    }
  }

  Future<void> _saveVideo(AdminSettings current) async {
    final url = _videoUrlCtrl.text.trim();
    if (url.isNotEmpty) {
      final validation = StreamUrlValidator.validate(url);
      if (!validation.isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(validation.error!), backgroundColor: Colors.red),
          );
        }
        return;
      }
    }

    final updated = current.copyWith(
      videoUrl: url,
      videoMatchName: _videoNameCtrl.text.trim(),
      updatedAt: DateTime.now(),
    );
    await ref.read(adminSettingsProvider.notifier).save(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video source saved')),
      );
    }
  }

  void _previewVideo() {
    final url = _videoUrlCtrl.text.trim();
    final validation = StreamUrlValidator.validate(url);
    if (!validation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation.error!), backgroundColor: Colors.red),
      );
      return;
    }
    final name = _videoNameCtrl.text.trim().isNotEmpty
        ? _videoNameCtrl.text.trim()
        : 'Live Preview';
    context.push(
      '/admin-video?url=${Uri.encodeComponent(url)}&title=${Uri.encodeComponent(name)}',
      extra: {'url': url, 'title': name},
    );
  }

  Future<void> _clearVideo() async {
    final current = ref.read(adminSettingsProvider).valueOrNull ?? const AdminSettings();
    final cleared = current.copyWith(videoUrl: '', videoMatchName: '');
    await ref.read(adminSettingsProvider.notifier).save(cleared);
    _videoUrlCtrl.clear();
    _videoNameCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video source cleared')),
      );
    }
  }
}
