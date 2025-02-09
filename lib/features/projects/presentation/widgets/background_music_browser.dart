import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/services/pixabay_service.dart';
import 'audio_waveform.dart';

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
  final _pixabayService = PixabayService();
  final _searchController = TextEditingController();
  final _audioPlayer = AudioPlayer();

  List<PixabayMusic> _musicList = [];
  bool _isLoading = false;
  String? _error;
  int? _playingIndex;
  String? _selectedCategory;

  final _categories = [
    'All',
    'Film',
    'Ambient',
    'Corporate',
    'Jazz',
    'Rock',
    'Classical',
    'Pop',
  ];

  @override
  void initState() {
    super.initState();
    _searchMusic('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _audioPlayer.dispose();
    _pixabayService.dispose();
    super.dispose();
  }

  Future<void> _searchMusic(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _pixabayService.searchMusic(
        query: query,
        category: _selectedCategory == 'All' ? null : _selectedCategory,
      );
      setState(() {
        _musicList = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _playPreview(int index) async {
    if (_playingIndex == index) {
      await _audioPlayer.stop();
      setState(() => _playingIndex = null);
    } else {
      final music = _musicList[index];
      try {
        await _audioPlayer.setUrl(music.previewUrl);
        await _audioPlayer.play();
        setState(() => _playingIndex = index);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing preview: $e')),
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
        child: Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
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

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(music.title),
            subtitle: Text(music.user),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(music.duration),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                  onPressed: () => _playPreview(index),
                ),
              ],
            ),
            onTap: () async {
              final path =
                  await _pixabayService.downloadMusic(music.downloadUrl);
              if (mounted) {
                widget.onMusicSelected(path);
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
