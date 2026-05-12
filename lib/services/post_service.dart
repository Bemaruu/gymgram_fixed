import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post.dart';
import 'badge_service.dart';
import 'image_compressor.dart';

class PostService {
  // Lista local para compatibilidad con pantallas que aún la usan
  static List<Post> posts = [];

  static final PostService instance = PostService._();
  PostService._();

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  // Carga los posts del feed desde Supabase (limit 30 por defecto para egress).
  Future<List<Map<String, dynamic>>> getFeedPosts({int limit = 30}) async {
    final result = await _client
        .from('posts')
        .select('id, user_id, media_url, media_type, caption, likes_count, comments_count, created_at, profiles(username, avatar_url)')
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(result);
  }

  // Sube media al bucket 'posts/{uid}/{filename}' y devuelve la URL pública.
  // Límites separados para imagen (5 MB) y video (10 MB) para cuidar egress.
  Future<String> uploadMedia(File file, {required String mediaType}) async {
    final uid = _uid;
    if (uid == null) throw Exception('No hay usuario autenticado');
    const allowed = ['jpg', 'jpeg', 'png', 'heic', 'webp', 'mp4', 'mov'];
    final ext = file.path.split('.').last.toLowerCase();
    if (!allowed.contains(ext)) {
      throw Exception('Formato de archivo no permitido.');
    }
    final maxBytes = mediaType == 'image'
        ? 5 * 1024 * 1024
        : 10 * 1024 * 1024;
    final size = await file.length();
    if (size > maxBytes) {
      final mb = (maxBytes / (1024 * 1024)).toStringAsFixed(0);
      throw Exception('El archivo supera el límite de $mb MB.');
    }
    final fileToUpload = mediaType == 'image'
        ? await ImageCompressor.compress(file)
        : file;
    final uploadExt = mediaType == 'image' ? 'jpg' : ext;
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$uploadExt';
    await _client.storage.from('posts').upload(path, fileToUpload);
    return _client.storage.from('posts').getPublicUrl(path);
  }

  // Crea un post en Supabase
  Future<void> createPost({
    required String mediaUrl,
    required String mediaType,   // 'image' o 'video'
    required String caption,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('No hay usuario autenticado');
    await _client.from('posts').insert({
      'user_id': uid,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'caption': caption,
    });
    await BadgeService.instance.checkAndAwardBadges(uid, 'post_created');
  }

  // Posts del usuario actual
  Future<List<Map<String, dynamic>>> getUserPosts() async {
    final uid = _uid;
    if (uid == null) return [];
    final result = await _client
        .from('posts')
        .select('id, media_url, media_type, caption, likes_count, comments_count, created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  // Elimina un post (solo el dueño puede, RLS lo garantiza)
  Future<void> deletePost(String postId) async {
    await _client.from('posts').delete().eq('id', postId);
  }

  // Edita el caption de un post
  Future<void> updatePost(String postId, String caption) async {
    await _client.from('posts').update({'caption': caption}).eq('id', postId);
  }

  // Toggle de like: inserta o borra el registro
  Future<void> toggleLike(String postId) async {
    final uid = _uid;
    if (uid == null) return;
    final existing = await _client
        .from('likes')
        .select('id')
        .eq('user_id', uid)
        .eq('post_id', postId)
        .maybeSingle();
    if (existing == null) {
      await _client.from('likes').insert({'user_id': uid, 'post_id': postId});
      await BadgeService.instance.checkAndAwardBadges(uid, 'like_given');
    } else {
      await _client.from('likes').delete().eq('id', existing['id']);
    }
  }

  // Verifica si el usuario actual le dio like a un post
  Future<bool> hasLiked(String postId) async {
    final uid = _uid;
    if (uid == null) return false;
    final result = await _client
        .from('likes')
        .select('id')
        .eq('user_id', uid)
        .eq('post_id', postId)
        .maybeSingle();
    return result != null;
  }

  // Cuenta los likes reales de un post desde la tabla likes
  Future<int> getLikesCount(String postId) async {
    final result = await _client
        .from('likes')
        .select('id')
        .eq('post_id', postId);
    return (result as List).length;
  }

  // Agrega un comentario
  Future<void> addComment(String postId, String content) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('comments').insert({
      'user_id': uid,
      'post_id': postId,
      'content': content,
    });
  }

  // Trae los comentarios de un post
  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final result = await _client
        .from('comments')
        .select('id, content, created_at, profiles(username, avatar_url)')
        .eq('post_id', postId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(result);
  }

  // ── Guardados (saved_posts) ───────────────────────────────────────────────
  Future<void> toggleSavePost(String postId) async {
    final uid = _uid;
    if (uid == null) return;
    final existing = await _client
        .from('saved_posts')
        .select('id')
        .eq('user_id', uid)
        .eq('post_id', postId)
        .maybeSingle();
    if (existing == null) {
      await _client.from('saved_posts').insert({
        'user_id': uid,
        'post_id': postId,
      });
    } else {
      await _client.from('saved_posts').delete().eq('id', existing['id']);
    }
  }

  Future<bool> isPostSaved(String postId) async {
    final uid = _uid;
    if (uid == null) return false;
    final result = await _client
        .from('saved_posts')
        .select('id')
        .eq('user_id', uid)
        .eq('post_id', postId)
        .maybeSingle();
    return result != null;
  }

  // Posts guardados del usuario actual (para el tab "Guardados" del perfil propio)
  Future<List<Map<String, dynamic>>> getSavedPosts() async {
    final uid = _uid;
    if (uid == null) return [];
    final result = await _client
        .from('saved_posts')
        .select('post_id, posts(id, user_id, media_url, media_type, caption, likes_count, comments_count, created_at)')
        .eq('user_id', uid)
        .order('saved_at', ascending: false);
    final list = List<Map<String, dynamic>>.from(result);
    // Aplanar: devolver el contenido del post directamente
    return list
        .map((row) => row['posts'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .toList();
  }
}
