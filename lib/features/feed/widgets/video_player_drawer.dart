import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../models/card.dart';
import '../../../theme/colors.dart';

class VideoPlayerDrawer extends StatefulWidget {
  final ContentCard card;
  const VideoPlayerDrawer({super.key, required this.card});

  @override
  State<VideoPlayerDrawer> createState() => _VideoPlayerDrawerState();
}

class _VideoPlayerDrawerState extends State<VideoPlayerDrawer> {
  late final YoutubePlayerController _controller;

  bool get _isHe => widget.card.language == 'he';

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.card.youtubeId!,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
        enableCaption: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Directionality(
      textDirection: _isHe ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayer(
                  controller: _controller,
                  aspectRatio: 16 / 9,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.card.headline,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge!
                          .copyWith(height: 1.25),
                    ),
                    if (widget.card.channel != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.card.channel!,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final id = widget.card.youtubeId;
                        if (id == null) return;
                        await launchUrl(
                          Uri.parse('https://www.youtube.com/watch?v=$id'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(_isHe ? 'פתח ביוטיוב' : 'Open on YouTube'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.divider),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
