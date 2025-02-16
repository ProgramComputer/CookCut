import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../../data/services/jamendo_service.dart';
import 'audio_waveform.dart';
import 'dart:async';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/media_bloc.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/background_music.dart';
import 'package:uuid/uuid.dart';

class BackgroundMusicBrowser extends StatefulWidget {
  final Function(BackgroundMusic music) onMusicSelected;
  final VoidCallback onCancel;
  final String projectId;
  final Duration videoDuration; // Add video duration to sync with
  final Function(Duration position)?
      onPreviewPositionChanged; // Callback for video sync

  const BackgroundMusicBrowser({
    Key? key,
    required this.onMusicSelected,
    required this.onCancel,
    required this.projectId,
    required this.videoDuration,
    this.onPreviewPositionChanged,
  }) : super(key: key);

  @override
  State<BackgroundMusicBrowser> createState() => _BackgroundMusicBrowserState();
}

class _BackgroundMusicBrowserState extends State<BackgroundMusicBrowser>
    with SingleTickerProviderStateMixin {
  final _jamendoService = JamendoService();
  final _searchController = TextEditingController();
  late final AudioPlayer _audioPlayer;
  late final TabController _tabController;
  bool _isAudioInitialized = false;

  // New state variables for music configuration
  double _startTime = 0.0;
  double _endTime = 0.0;
  double _volume = 0.7; // Default to 70% volume
  bool _isPreviewingWithVideo = false;
  String? _selectedMusicUrl;
  String? _selectedMusicTitle;
  String? _selectedMusicArtist;
  Duration _currentPosition = Duration.zero;
  Timer? _videoSyncTimer;

  List<JamendoMusic> _jamendoTracks = [];
  List<MediaAsset> _localTracks = [];
  bool _isLoading = false;
  String? _error;
  int? _playingIndex;
  String? _selectedCategory;
  bool _isPlaybackLoading = false;
  int? _loadingIndex;
  Map<int, double> _loadingProgress = {};
  final Map<String, FileInfo?> _cachedThumbnails = {};
  final Map<String, FileInfo?> _cachedPreviews = {};

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
    _tabController = TabController(length: 2, vsync: this);
    _initAudio();
    _loadInitialMusic();
    _loadProjectAudio();

    // Initialize end time to video duration
    _endTime = widget.videoDuration.inSeconds.toDouble();

    // Listen to audio player position changes
    _audioPlayer.positionStream.listen((position) {
      if (_isPreviewingWithVideo && widget.onPreviewPositionChanged != null) {
        widget.onPreviewPositionChanged!(position);
      }
      setState(() {
        _currentPosition = position;
      });
    });
  }

  @override
  void dispose() {
    _videoSyncTimer?.cancel();
    _searchDebouncer?.cancel();
    _searchController.dispose();
    _audioPlayer.dispose();
    _jamendoService.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProjectAudio() async {
    final mediaBloc = context.read<MediaBloc>();
    mediaBloc.add(LoadProjectMedia(widget.projectId));
  }

  Future<void> _initAudio() async {
    try {
      _audioPlayer = AudioPlayer();
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
      ));
      setState(() {
        _isAudioInitialized = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Error initializing audio: $e';
      });
    }
  }

  Future<void> _loadInitialMusic() async {
    await _searchMusic('');
  }

  Future<FileInfo?> _getCachedFile(String url, bool isPreview) async {
    final cache = isPreview ? _cachedPreviews : _cachedThumbnails;
    if (cache.containsKey(url)) {
      return cache[url];
    }

    try {
      final fileInfo = await JamendoCacheManager.instance.getFileFromCache(url);
      if (fileInfo != null) {
        cache[url] = fileInfo;
        return fileInfo;
      }

      final downloadedFile = await JamendoCacheManager.instance.downloadFile(
        url,
        key: url,
      );
      cache[url] = downloadedFile;
      return downloadedFile;
    } catch (e) {
      print('Error caching file $url: $e');
      return null;
    }
  }

  Future<void> _searchMusic(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tracks = await _jamendoService.searchMusic(
        query: query,
        tags: _selectedCategory == 'All' ? null : _selectedCategory,
      );

      if (!mounted) return;

      setState(() {
        _jamendoTracks = tracks;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _playPreview(int index, bool isJamendo) async {
    if (_isPlaybackLoading || _loadingIndex != null) return;

    String? url;
    if (isJamendo) {
      if (index >= _jamendoTracks.length) return;
      url = _jamendoTracks[index].previewUrl;
    } else {
      // Get audio assets from the MediaBloc state
      final audioAssets = context
          .read<MediaBloc>()
          .state
          .assets
          .where((asset) => asset.type == MediaType.audio)
          .toList();

      if (index >= audioAssets.length) return;
      url = audioAssets[index].fileUrl;
    }

    if (url == null) return;

    setState(() {
      _loadingIndex = index;
      _loadingProgress[index] = 0;
    });

    try {
      // Try to get cached preview
      if (isJamendo) {
        final cachedPreview = await _getCachedFile(url, true);
        if (cachedPreview != null) {
          await _audioPlayer.setFilePath(cachedPreview.file.path);
        } else {
          await _audioPlayer.setUrl(url, preload: true);
        }
      } else {
        await _audioPlayer.setUrl(url, preload: true);
      }

      if (!mounted) return;

      setState(() {
        _playingIndex = index;
        _loadingIndex = null;
        _loadingProgress.remove(index);
      });

      await _audioPlayer.play();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingIndex = null;
        _loadingProgress.remove(index);
        _error = 'Error playing preview: $e';
      });
    }
  }

  // New method to handle music selection
  void _handleMusicSelection(String url, String title, [String? artist]) {
    setState(() {
      _selectedMusicUrl = url;
      _selectedMusicTitle = title;
      _selectedMusicArtist = artist;
    });

    // Reset configuration when new music is selected
    setState(() {
      _startTime = 0.0;
      _endTime = widget.videoDuration.inSeconds.toDouble();
      _volume = 0.7;
      _isPreviewingWithVideo = false;
    });
  }

  // New method to save music configuration
  void _saveConfiguration() {
    if (_selectedMusicUrl == null) return;

    final music = BackgroundMusic(
      id: const Uuid().v4(),
      projectId: widget.projectId,
      url: _selectedMusicUrl!,
      title: _selectedMusicTitle!,
      artist: _selectedMusicArtist,
      volume: _volume,
      startTime: _startTime,
      endTime: _endTime,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    widget.onMusicSelected(music);
  }

  // New method to preview with video
  void _toggleVideoPreview() {
    setState(() {
      _isPreviewingWithVideo = !_isPreviewingWithVideo;
    });

    if (_isPreviewingWithVideo) {
      // Start playback from start time
      _audioPlayer.seek(Duration(seconds: _startTime.toInt()));
      _audioPlayer.play();
    } else {
      _audioPlayer.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Background Music',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Jamendo'),
            Tab(text: 'Project Audio'),
          ],
        ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildJamendoTab(),
                    _buildLocalTab(),
                  ],
                ),
              ),
              if (_selectedMusicUrl != null) _buildMusicConfigurationPanel(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 32,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed:
                        _selectedMusicUrl != null ? _saveConfiguration : null,
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMusicConfigurationPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _selectedMusicTitle ?? 'Selected Music',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_selectedMusicArtist != null)
            Text(
              _selectedMusicArtist!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 16),
          // Waveform visualization with current position
          SizedBox(
            height: 60,
            child: AudioWaveform(
              url: _selectedMusicUrl!,
              position: _currentPosition,
              onPositionChanged: (position) {
                _audioPlayer.seek(position);
              },
              startTime: Duration(seconds: _startTime.toInt()),
              endTime: Duration(seconds: _endTime.toInt()),
            ),
          ),
          const SizedBox(height: 16),
          // Start Time Slider
          Row(
            children: [
              const SizedBox(width: 100, child: Text('Start Time:')),
              Expanded(
                child: Slider(
                  value: _startTime,
                  min: 0,
                  max: widget.videoDuration.inSeconds.toDouble(),
                  onChanged: (value) {
                    setState(() {
                      _startTime = value;
                      if (_startTime > _endTime) {
                        _endTime = _startTime;
                      }
                    });
                  },
                  label: Duration(seconds: _startTime.toInt())
                      .toString()
                      .split('.')
                      .first,
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  Duration(seconds: _startTime.toInt())
                      .toString()
                      .split('.')
                      .first,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          // End Time Slider
          Row(
            children: [
              const SizedBox(width: 100, child: Text('End Time:')),
              Expanded(
                child: Slider(
                  value: _endTime,
                  min: 0,
                  max: widget.videoDuration.inSeconds.toDouble(),
                  onChanged: (value) {
                    setState(() {
                      _endTime = value;
                      if (_endTime < _startTime) {
                        _startTime = _endTime;
                      }
                    });
                  },
                  label: Duration(seconds: _endTime.toInt())
                      .toString()
                      .split('.')
                      .first,
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  Duration(seconds: _endTime.toInt())
                      .toString()
                      .split('.')
                      .first,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          // Volume Slider
          Row(
            children: [
              const SizedBox(width: 100, child: Text('Volume:')),
              Expanded(
                child: Slider(
                  value: _volume,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  onChanged: (value) {
                    setState(() {
                      _volume = value;
                      _audioPlayer.setVolume(value);
                    });
                  },
                  label: '${(_volume * 100).toInt()}%',
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  '${(_volume * 100).toInt()}%',
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          // Preview Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_audioPlayer.playing) {
                        _audioPlayer.pause();
                      } else {
                        _audioPlayer
                            .seek(Duration(seconds: _startTime.toInt()));
                        _audioPlayer.play();
                      }
                    },
                    icon: Icon(
                        _audioPlayer.playing ? Icons.pause : Icons.play_arrow),
                    label: const Text('Preview Music'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: ElevatedButton.icon(
                    onPressed: _toggleVideoPreview,
                    icon:
                        Icon(_isPreviewingWithVideo ? Icons.stop : Icons.movie),
                    label: Text(_isPreviewingWithVideo
                        ? 'Stop Preview'
                        : 'Preview with Video'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJamendoTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search music...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              _searchDebouncer?.cancel();
              _searchDebouncer = Timer(const Duration(milliseconds: 500), () {
                _searchMusic(value);
              });
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _categories.map((category) {
              final isSelected = _selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  label: Text(category),
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
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        if (_isLoading)
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _jamendoTracks.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final track = _jamendoTracks[index];
                final isPlaying = _playingIndex == index;
                final isLoading = _loadingIndex == index;
                final progress = _loadingProgress[index] ?? 0;
                final isSelected = _selectedMusicUrl == track.audioUrl;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: ListTile(
                    leading: SizedBox(
                      width: 56,
                      height: 56,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: FutureBuilder<FileInfo?>(
                          future: _getCachedFile(track.thumbnailUrl, false),
                          builder: (context, snapshot) {
                            final hasImage =
                                snapshot.hasData && snapshot.data != null;
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: hasImage
                                  ? Image.file(
                                      snapshot.data!.file,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.music_note,
                                          color: Colors.white54),
                                    ),
                            );
                          },
                        ),
                      ),
                    ),
                    title: Text(
                      track.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 64,
                          child: Text(
                            track.duration,
                            textAlign: TextAlign.end,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isLoading)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        else
                          SizedBox(
                            width: 40,
                            child: IconButton(
                              icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow),
                              onPressed: () {
                                if (isPlaying) {
                                  _audioPlayer.pause();
                                  setState(() {
                                    _playingIndex = null;
                                  });
                                } else {
                                  _playPreview(index, true);
                                }
                              },
                            ),
                          ),
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            icon: Icon(isSelected ? Icons.check : Icons.add),
                            onPressed: () {
                              _handleMusicSelection(
                                  track.audioUrl, track.name, track.artist);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildLocalTab() {
    return BlocBuilder<MediaBloc, MediaState>(
      builder: (context, state) {
        if (state.status == MediaStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == MediaStatus.error) {
          return Center(child: Text(state.error ?? 'Unknown error'));
        }

        final audioAssets = state.assets
            .where((asset) => asset.type == MediaType.audio)
            .toList();

        if (audioAssets.isEmpty) {
          return const Center(
            child: Text(
              'No project audio files found.\nUpload audio files through the media manager.',
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          itemCount: audioAssets.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final asset = audioAssets[index];
            final isPlaying = _playingIndex == index;
            final isLoading = _loadingIndex == index;
            final isSelected = _selectedMusicUrl == asset.fileUrl;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                leading: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.white54),
                ),
                title: Text(
                  asset.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Local Audio',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(asset.formattedDuration),
                    const SizedBox(width: 8),
                    if (isLoading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: () {
                          if (isPlaying) {
                            _audioPlayer.pause();
                            setState(() {
                              _playingIndex = null;
                            });
                          } else {
                            _playPreview(index, false);
                          }
                        },
                      ),
                    IconButton(
                      icon: Icon(isSelected ? Icons.check : Icons.add),
                      onPressed: () {
                        _handleMusicSelection(asset.fileUrl, asset.fileName);
                      },
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
}

class JamendoCacheManager {
  static const key = 'jamendoCache';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 100,
      fileService: HttpFileService(),
    ),
  );
}
