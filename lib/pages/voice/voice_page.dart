import 'package:flutter/material.dart';
import 'package:murmur/services/voice_service.dart';

class VoicePage extends StatefulWidget {
  const VoicePage({super.key});

  @override
  State<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends State<VoicePage> {
  List<VoiceOption> _recordings = <VoiceOption>[];
  bool _isPlaying = false;
  String _status = 'Voice ready';

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    final List<VoiceOption> list = await VoiceService.loadRecordings();
    if (!mounted) {
      return;
    }
    setState(() {
      _recordings = list;
    });
  }

  Future<void> _playVoice(VoiceOption option) async {
    setState(() {
      _isPlaying = true;
      _status = 'Playing voice...';
    });
    await VoiceService.play(voicePath: option.filePath, voiceId: option.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _isPlaying = false;
      _status = 'Voice ready';
    });
  }

  Future<void> _stopVoice() async {
    await VoiceService.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _isPlaying = false;
      _status = 'Voice stopped';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('声音')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(_status),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _isPlaying ? _stopVoice : null,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _loadRecordings,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Preset Voices', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...VoiceService.presetVoices.map((VoiceOption voice) {
            final bool isDefault = voice.id == VoiceService.defaultVoiceId;
            return Card(
              child: ListTile(
                title: Text(voice.name),
                subtitle: Text(isDefault ? 'Default selected' : 'Tap to preview'),
                trailing: Wrap(
                  spacing: 8,
                  children: <Widget>[
                    IconButton(
                      onPressed: () => _playVoice(voice),
                      icon: const Icon(Icons.play_arrow),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          VoiceService.setDefaultVoice(voice.id);
                        });
                      },
                      icon: Icon(
                        isDefault ? Icons.check_circle : Icons.radio_button_unchecked,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Text('My Recordings', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_recordings.isEmpty)
            const Text('No recordings yet')
          else
            ..._recordings.map((VoiceOption record) {
              final bool isDefault = record.id == VoiceService.defaultVoiceId;
              return Card(
                child: ListTile(
                  title: Text(record.name),
                  subtitle: Text(isDefault ? 'Default selected' : 'Local recording'),
                  trailing: Wrap(
                    spacing: 8,
                    children: <Widget>[
                      IconButton(
                        onPressed: () => _playVoice(record),
                        icon: const Icon(Icons.play_arrow),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            VoiceService.setDefaultVoice(record.id);
                          });
                        },
                        icon: Icon(
                          isDefault ? Icons.check_circle : Icons.radio_button_unchecked,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
