import 'package:flutter/material.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import 'edit_post_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Post post;
  bool showHeart = false;

  @override
  void initState() {
    super.initState();
    post = widget.post;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              _showOptions(context);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
GestureDetector(
  onDoubleTap: () {
    setState(() {
      showHeart = true;

      if (!post.isLiked) {
        post.isLiked = true;
        post.likes++;
      }
    });

    // desaparecer corazón
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          showHeart = false;
        });
      }
    });
  },
  child: Hero(
    tag: post.image.path,
    child: Image.file(
      post.image,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
    ),
  ),
),
AnimatedOpacity(
  opacity: showHeart ? 1 : 0,
  duration: const Duration(milliseconds: 300),
  child: Center(
    child: Icon(
      Icons.favorite,
      color: Colors.red.withOpacity(0.9),
      size: 120,
    ),
  ),
),
  

          // 🔥 BOTONES DERECHA
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [

                // ❤️ LIKE
                IconButton(
                  icon: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: post.isLiked ? Colors.red : Colors.white,
                    size: 30,
                  ),
                  onPressed: () {
                    setState(() {
                      post.isLiked = !post.isLiked;
                      post.isLiked ? post.likes++ : post.likes--;
                    });
                  },
                ),

                Text(
                  '${post.likes}',
                  style: const TextStyle(color: Colors.white),
                ),

                const SizedBox(height: 20),

                // 🔗 SHARE
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white, size: 30),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // 🔥 INFO ABAJO
          Positioned(
            left: 16,
            bottom: 20,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '@usuario',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  post.caption,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 MENÚ OPCIONES
  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Eliminar publicación',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text(
                  'Editar publicación',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditPostScreen(
                        postId: '',
                        mediaUrl: '',
                        initialCaption: post.caption,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.white),
                title: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🔥 CONFIRMAR ELIMINACIÓN
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar publicación'),
        content: const Text('¿Seguro que quieres eliminar este post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              _deletePost(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // 🔥 BORRAR POST
  void _deletePost(BuildContext context) {
    PostService.posts.remove(post);

    Navigator.pop(context);
    Navigator.pop(context);
  }
}