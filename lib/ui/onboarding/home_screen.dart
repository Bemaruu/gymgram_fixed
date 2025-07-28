import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../data/simulated_ai/simulated_posts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: simulatedPosts.length,
        itemBuilder: (context, index) {
          final post = simulatedPosts[index];
          return PostWidget(post: post);
        },
      ),
    );
  }
}

class PostWidget extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostWidget({super.key, required this.post});

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.post['type'] == 'video') {
      _videoController = VideoPlayerController.asset(widget.post['file'])
        ..initialize().then((_) {
          setState(() {});
          _videoController!.play();
          _videoController!.setLooping(true);
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.post['type'] == 'video'
            ? (_videoController != null && _videoController!.value.isInitialized)
                ? VideoPlayer(_videoController!)
                : const Center(child: CircularProgressIndicator())
            : Image.asset(
                widget.post['file'],
                fit: BoxFit.cover,
              ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.7),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${widget.post['username']}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                widget.post['caption'],
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 20,
          right: 16,
          child: Column(
            children: const [
              Icon(Icons.favorite_border, color: Colors.white, size: 32),
              SizedBox(height: 12),
              Icon(Icons.comment, color: Colors.white, size: 32),
              SizedBox(height: 12),
              Icon(Icons.bookmark_border, color: Colors.white, size: 32),
            ],
          ),
        ),
      ],
    );
  }
}
