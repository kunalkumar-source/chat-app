import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/reels_provider.dart';
import '../../data/models/reel_model.dart';

class ReelsPage extends ConsumerWidget {
  const ReelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reelsAsync = ref.watch(reelsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Reels', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: reelsAsync.when(
        data: (reels) => PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: reels.length,
          onPageChanged: (index) {
            if (index >= reels.length - 2) {
              ref.read(reelsProvider.notifier).loadMore();
            }
          },
          itemBuilder: (context, index) {
            return ReelItem(reel: reels[index]);
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

class ReelItem extends StatefulWidget {
  final ReelModel reel;
  const ReelItem({super.key, required this.reel});

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final file = await DefaultCacheManager().getSingleFile(widget.reel.videoUrl);
      
      _controller = VideoPlayerController.file(file)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isInitialized = true;
              _controller?.play();
              _controller?.setLooping(true);
            });
          }
        });
    } catch (e) {
      debugPrint('Error loading video: $e');
    }
  }

  @override
  void dispose() {
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: () {
            if (_controller?.value.isPlaying ?? false) {
              _controller?.pause();
            } else {
              _controller?.play();
            }
          },
          child: Center(
            child: _isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : const CircularProgressIndicator(color: Colors.white),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black26, Colors.transparent, Colors.transparent, Colors.black54],
              stops: [0.0, 0.2, 0.7, 1.0],
            ),
          ),
        ),
        Positioned(
          bottom: 30,
          left: 15,
          right: 70,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: widget.reel.authorAvatar.isNotEmpty
                        ? CachedNetworkImageProvider(widget.reel.authorAvatar)
                        : null,
                    child: widget.reel.authorAvatar.isEmpty ? const Icon(Icons.person) : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.reel.authorUsername,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.reel.caption,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.reel.location.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(widget.reel.location, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.music_note, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.reel.music,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
