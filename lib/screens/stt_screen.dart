import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/stt_bloc.dart';
import '../bloc/stt_event.dart';
import '../bloc/stt_state.dart';
import '../widgets/language_selector.dart';
import '../widgets/recording_button.dart';
import '../constants/languages.dart';
import 'package:permission_handler/permission_handler.dart';

const String appVersion = '0.19';

class SttScreen extends StatefulWidget {
  const SttScreen({super.key});

  @override
  State<SttScreen> createState() => _SttScreenState();
}

class _SttScreenState extends State<SttScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize STT when screen loads
    context.read<SttBloc>().add(const InitializeStt());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('語音轉文字'),
        centerTitle: true,
        elevation: 0,
      ),
      body: BlocConsumer<SttBloc, SttState>(
        listener: (context, state) {
          if (state is SttError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is SttPermissionDenied) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('麥克風權限被拒絕。請在設定中啟用。'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Language Selector
                  if (state is SttReady ||
                      state is SttListening ||
                      state is SttResult)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('說話 (來源)',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              LanguageSelector(
                                currentLanguage: _getCurrentLanguage(state),
                                onLanguageChanged: (languageCode) {
                                  context
                                      .read<SttBloc>()
                                      .add(ChangeLanguage(languageCode));
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.arrow_forward),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('翻譯成 (目標)',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              LanguageSelector(
                                currentLanguage: _getTargetLanguage(state),
                                onLanguageChanged: (languageCode) {
                                  context
                                      .read<SttBloc>()
                                      .add(ChangeTargetLanguage(languageCode));
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  // Download Language Pack Button — always visible
                  TextButton.icon(
                    onPressed: () {
                      context.read<SttBloc>().add(const OpenLanguageSettings());
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('下載語言包'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Status Indicator
                  _buildStatusIndicator(state),

                  const SizedBox(height: 32),

                  // Transcription Display
                  Expanded(
                    flex: 1,
                    child: _buildTranscriptionDisplay(state),
                  ),

                  const SizedBox(height: 16),

                  Expanded(
                    flex: 1,
                    child: _buildTranslationDisplay(state),
                  ),

                  const SizedBox(height: 32),

                  // Recording Button
                  _buildRecordingButton(state),

                  const SizedBox(height: 16),
                  const SizedBox(height: 16),

                  // Version Display
                  Text(
                    '版本: $appVersion',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getTargetLanguage(SttState state) {
    if (state is SttReady) return state.targetLanguage;
    if (state is SttListening) return state.targetLanguage;
    if (state is SttResult) return state.targetLanguage;
    return Languages.traditionalChinese.code;
  }

  String _getCurrentLanguage(SttState state) {
    if (state is SttReady) return state.currentLanguage;
    if (state is SttListening) return state.currentLanguage;
    if (state is SttResult) return state.currentLanguage;
    if (state is SttError && state.currentLanguage != null) {
      return state.currentLanguage!;
    }
    return Languages.english.code;
  }

  Widget _buildStatusIndicator(SttState state) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (state is SttInitializing) {
      statusText = '初始化中...';
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
    } else if (state is SttListening) {
      statusText = '聆聽中...';
      statusColor = Colors.red;
      statusIcon = Icons.mic;
    } else if (state is SttReady) {
      statusText = '就緒';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (state is SttPermissionDenied) {
      statusText = '權限被拒絕';
      statusColor = Colors.red;
      statusIcon = Icons.error;
    } else if (state is SttError) {
      statusText = '錯誤';
      statusColor = Colors.red;
      statusIcon = Icons.error;
    } else if (state is SttDownloadingModel) {
      statusText = state.message;
      statusColor = Colors.blue;
      statusIcon = Icons.download;
    } else {
      statusText = '未初始化';
      statusColor = Colors.grey;
      statusIcon = Icons.info;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(statusIcon, color: statusColor, size: 24),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ],
        ),
        if (state is SttError)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              state.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.withValues(alpha: 0.8),
              ),
            ),
          ),
        if (state is SttError || state is SttPermissionDenied)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<SttBloc>().add(const RetryStt());
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('重試'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.withValues(alpha: 0.15),
                        foregroundColor: Colors.orange,
                      ),
                    ),
                    if (state is SttPermissionDenied) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => openAppSettings(),
                        icon: const Icon(Icons.settings),
                        label: const Text('打開設定'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
                if (state is SttError &&
                    (state.message.contains('language_unavailable') ||
                        state.message.contains('語言模型未下載') ||
                        state.message
                            .contains('error_language_not_supported') ||
                        state.message.contains('不支援此語言')))
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context
                            .read<SttBloc>()
                            .add(const OpenLanguageSettings());
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('下載語言包'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.withValues(alpha: 0.15),
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTranscriptionDisplay(SttState state) {
    String transcription = '';

    if (state is SttListening) {
      transcription = state.transcription;
    } else if (state is SttResult) {
      transcription = state.transcription;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: SingleChildScrollView(
        child: Text(
          transcription.isEmpty ? '點擊麥克風開始，然後說話...' : transcription,
          style: TextStyle(
            fontSize: 18,
            height: 1.5,
            color: transcription.isEmpty
                ? Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.5)
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildTranslationDisplay(SttState state) {
    String translation = '';

    if (state is SttListening) {
      translation = state.translatedText;
    } else if (state is SttResult) {
      translation = state.translatedText;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '翻譯:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                translation.isEmpty ? '...' : translation,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: translation.isEmpty
                      ? Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.5)
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingButton(SttState state) {
    final isListening = state is SttListening;
    final isEnabled = state is SttReady || state is SttListening;

    return RecordingButton(
      isListening: isListening,
      isEnabled: isEnabled,
      onPressed: () {
        if (isListening) {
          context.read<SttBloc>().add(const StopListening());
        } else {
          context.read<SttBloc>().add(const StartListening());
        }
      },
    );
  }
}
