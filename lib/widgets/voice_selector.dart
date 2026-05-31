import 'package:flutter/material.dart';
import 'package:murmur/services/voice_service.dart';

class SelectedVoice {
  const SelectedVoice({
    required this.soundId,
    this.voiceId,
    this.voicePath,
    this.isCustomVoice = false,
    required this.label,
  });

  final String soundId;
  final String? voiceId;
  final String? voicePath;
  final bool isCustomVoice;
  final String label;
}

class VoiceSelector extends StatefulWidget {
  const VoiceSelector({
    super.key,
    required this.onChanged,
    this.initialVoiceId,
    this.initialVoicePath,
    this.initialIsCustomVoice = false,
  });

  final ValueChanged<SelectedVoice> onChanged;
  final String? initialVoiceId;
  final String? initialVoicePath;
  final bool initialIsCustomVoice;

  @override
  State<VoiceSelector> createState() => _VoiceSelectorState();
}

class _VoiceSelectorState extends State<VoiceSelector> {
  String _selectedId = 'default';
  List<VoiceOption> _recordings = <VoiceOption>[];
  String? _recordingPath;
  DateTime? _recordingStartedAt;
  bool _isRecording = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialIsCustomVoice &&
        widget.initialVoicePath != null &&
        widget.initialVoicePath!.isNotEmpty) {
      _selectedId = 'my_recorded_voice';
      _recordingPath = widget.initialVoicePath;
    } else if (widget.initialVoiceId != null &&
        widget.initialVoiceId!.isNotEmpty) {
      _selectedId = widget.initialVoiceId!;
    }
    _loadRecordings();
    _notifySelection();
  }

  Future<void> _loadRecordings() async {
    final List<VoiceOption> recordings = await VoiceService.loadRecordings();
    if (!mounted) {
      return;
    }
    setState(() {
      _recordings = recordings;
      if (_recordingPath == null && recordings.isNotEmpty) {
        _recordingPath = recordings.first.filePath;
      }
    });
  }

  Future<void> _toggleRecord() async {
    if (_isRecording) {
      final String? path = await VoiceService.stopRecording();
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = false;
        _recordingStartedAt = null;
        if (path != null && path.isNotEmpty) {
          _recordingPath = path;
          _selectedId = 'my_recorded_voice';
        }
      });
      await _loadRecordings();
      _notifySelection();
      return;
    }

    try {
      await VoiceService.startRecording();
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = true;
        _recordingStartedAt = DateTime.now();
      });

      Future<void>.delayed(const Duration(seconds: 30), () async {
        if (_isRecording) {
          await _toggleRecord();
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('录音权限不可用')),
      );
    }
  }

  Future<void> _preview() async {
    if (_isPlaying) {
      await VoiceService.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
      });
      return;
    }

    final SelectedVoice selected = _currentSelected();
    await VoiceService.play(
      voicePath: selected.voicePath,
      voiceId: selected.voiceId ?? selected.soundId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isPlaying = true;
    });
  }

  void _notifySelection() {
    widget.onChanged(_currentSelected());
  }

  SelectedVoice _currentSelected() {
    if (_selectedId == 'my_recorded_voice' && _recordingPath != null) {
      return SelectedVoice(
        soundId: 'my_recorded_voice',
        voiceId: 'my_recorded_voice',
        voicePath: _recordingPath,
        isCustomVoice: true,
        label: 'My Recorded Voice',
      );
    }

    final VoiceOption preset = VoiceService.presetVoices.firstWhere(
      (VoiceOption item) => item.id == _selectedId,
      orElse: () => VoiceService.presetVoices.first,
    );
    return SelectedVoice(
      soundId: preset.id,
      voiceId: preset.id,
      label: preset.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Voice Selection',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedId,
          items: <DropdownMenuItem<String>>[
            ...VoiceService.presetVoices.map(
              (VoiceOption voice) => DropdownMenuItem<String>(
                value: voice.id,
                child: Text(voice.name),
              ),
            ),
            const DropdownMenuItem<String>(
              value: 'my_recorded_voice',
              child: Text('My Recorded Voice'),
            ),
          ],
          onChanged: (String? value) {
            if (value == null) {
              return;
            }
            setState(() {
              _selectedId = value;
            });
            _notifySelection();
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _toggleRecord,
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(_isRecording ? '停止录音' : '录音（最多30秒）'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _preview,
              icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
              label: Text(_isPlaying ? 'Stop' : 'Preview'),
            ),
          ],
        ),
        if (_isRecording && _recordingStartedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Recording...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (_recordings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'My recordings: ${_recordings.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
