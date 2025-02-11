import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../../data/services/jamendo_service.dart';
import 'audio_waveform.dart';
import 'dart:async';

class BackgroundMusicBrowser extends StatefulWidget {
  final Function(String path) onMusicSelected;
  final VoidCallback onCancel;

  const BackgroundMusicBrowser({
    Key? key,
    required this.onMusicSelected,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<BackgroundMusicBrowser> createState() => _BackgroundMusicBrowserState();
}

class _BackgroundMusicBrowserState extends State<BackgroundMusicBrowser> {
  final _jamendoService = JamendoService();
  final _searchController = TextEditingController();
  late final AudioPlayer _audioPlayer;
  bool _isAudioInitialized = false;

  List<JamendoMusic> _musicList = [];
  bool _isLoading = false;
  String? _error;
  int? _playingIndex;
  String? _selectedCategory;
  bool _isPlaybackLoading = false;
  int? _loadingIndex;
  Map<int, double> _loadingProgress = {}; // Track progress per index

  // Debouncer for search
  Timer? _searchDebouncer;

  final _categories = [
    'All',
    'ambient',
    'classical',
    'electronic',
    'jazz',
    'lounge',
    'pop',
    'rock',
    'soundtrack',
  ];

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    _searchMusic('');
  }

  @override
  void dispose() {
    _searchDebouncer?.cancel();
    _searchController.dispose();
    _audioPlayer.dispose();
    _jamendoService.dispose();
    super.dispose();
  }

  Future<void> _initAudioPlayer() async {
    try {
      _audioPlayer = AudioPlayer();
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
      ));
      setState(() => _isAudioInitialized = true);
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize audio player: $e';
        _isAudioInitialized = false;
      });
    }
  }

  Future<void> _searchMusic(String query) async {
    // Cancel any pending search
    _searchDebouncer?.cancel();

    // Debounce the search to prevent too many API calls
    _searchDebouncer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        final results = await _jamendoService.searchMusic(
          query: query,
          tags: _selectedCategory == 'All' ? null : _selectedCategory,
        );
        if (mounted) {
          setState(() {
            _musicList = results;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = e.toString();
            _isLoading = false;
          });
        }
      }
    });
  }

  Future<void> _playPreview(int index) async {
    if (!_isAudioInitialized || _isPlaybackLoading) {
      return;
    }

    if (_playingIndex == index) {
      await _audioPlayer.stop();
      setState(() => _playingIndex = null);
      return;
    }

    setState(() {
      _isPlaybackLoading = true;
      _loadingIndex = index;
    });

    try {
      final music = _musicList[index];

      // Stop current playback
      await _audioPlayer.stop();

      // Get cached or download URL
      final audioUrl = await _jamendoService.downloadMusic(music.audioUrl);

      if (!mounted) return;

      // Set the audio source and start playback
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();

      setState(() {
        _playingIndex = index;
        _isPlaybackLoading = false;
        _loadingIndex = null;
      });

      // Add completion listener
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && mounted) {
          setState(() => _playingIndex = null);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlaybackLoading = false;
          _loadingIndex = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing preview: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Background Music',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildCategoryFilter(),
            const SizedBox(height: 16),
            Expanded(
              child: _buildMusicList(),
            ),
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search music...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onSubmitted: _searchMusic,
    );
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? category : null;
                });
                _searchMusic(_searchController.text);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMusicList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() => _error = null);
                _initAudioPlayer();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_musicList.isEmpty) {
      return const Center(
        child: Text('No music found. Try a different search.'),
      );
    }

    return ListView.builder(
      itemCount: _musicList.length,
      itemBuilder: (context, index) {
        final music = _musicList[index];
        final isPlaying = _playingIndex == index;
        final isLoading = _loadingIndex == index;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(music.name),
            subtitle: Text(music.artist),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(music.duration),
                const SizedBox(width: 8),
                if (isLoading)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: _loadingProgress[index] ?? 0.0,
                    ),
                  )
                else
                  IconButton(
                    icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                    onPressed: () => _playPreview(index),
                  ),
              ],
            ),
            onTap: () async {
              if (_isPlaybackLoading) {
                print('Ignoring tap - already loading');
                return;
              }

              final currentIndex = index;
              print('Starting download for track at index $currentIndex');
              setState(() {
                _isPlaybackLoading = true;
                _loadingIndex = currentIndex;
                _loadingProgress[currentIndex] = 0.0;
              });
              print('Initial state set - loading: true, progress: 0%');

              try {
                final path = await _jamendoService.downloadMusic(
                  music.audioUrl,
                  onProgress: (progress) {
                    if (mounted) {
                      print(
                          'Progress update for index $currentIndex: ${(progress * 100).toStringAsFixed(1)}%');
                      setState(() {
                        _loadingProgress[currentIndex] = progress;
                      });
                    }
                  },
                );
                print('Download completed successfully. Path: $path');
                if (mounted) {
                  widget.onMusicSelected(path);
                }
              } catch (e) {
                print('Error during download: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error selecting music: ${e.toString()}'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  print('Cleaning up state for index $currentIndex');
                  setState(() {
                    _isPlaybackLoading = false;
                    _loadingIndex = null;
                    _loadingProgress.remove(currentIndex);
                  });
                }
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
