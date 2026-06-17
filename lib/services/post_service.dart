import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post.dart';
import 'badge_service.dart';
import 'image_compressor.dart';
import 'video_compressor.dart';

String _contentTypeFor(String ext) {
  switch (ext.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    default:
      return 'application/octet-stream';
  }
}

class PostService {
  // Lista local para compatibilidad con pantallas que aún la usan
  static List<Post> posts = [];

  /// Máximo de imágenes por carrusel (inspirado en Instagram).
  static const int maxCarouselImages = 10;

  static final PostService instance = PostService._();
  PostService._();

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  /// Extrae la lista ordenada de media de un post sin importar la forma del
  /// mapa: feed RPC trae `media` (List), los selects con embed traen
  /// `post_media` (List con `position`), y los posts antiguos solo traen
  /// `media_url`/`media_type`. Siempre devuelve al menos 1 elemento.
  static List<({String url, String type})> mediaOf(Map<String, dynamic> post) {
    final result = <({String url, String type})>[];

    final media = post['media'];
    if (media is List && media.isNotEmpty) {
      for (final m in media) {
        if (m is Map) {
          final url = (m['media_url'] as String?) ?? '';
          if (url.isNotEmpty) {
            result.add((url: url, type: (m['media_type'] as String?) ?? 'image'));
          }
        }
      }
    }

    if (result.isEmpty) {
      final embed = post['post_media'];
      if (embed is List && embed.isNotEmpty) {
        final rows = List<Map<String, dynamic>>.from(embed)
          ..sort((a, b) =>
              ((a['position'] as int?) ?? 0).compareTo((b['position'] as int?) ?? 0));
        for (final m in rows) {
          final url = (m['media_url'] as String?) ?? '';
          if (url.isNotEmpty) {
            result.add((url: url, type: (m['media_type'] as String?) ?? 'image'));
          }
        }
      }
    }

    if (result.isEmpty) {
      final url = (post['media_url'] as String?) ?? '';
      result.add((url: url, type: (post['media_type'] as String?) ?? 'image'));
    }

    return result;
  }

  // Feed rankeado por el algoritmo de GymGram (RPC en Supabase).
  // Score = (likes×1 + comments×3 + saves×5 + 1) × time_decay × social_boost
  Future<List<Map<String, dynamic>>> getFeedPosts({int limit = 30, int offset = 0}) async {
    final uid = _uid;
    if (uid == null) return [];
    final result = await _client.rpc('get_ranked_feed', params: {
      'p_user_id': uid,
      'p_limit': limit,
      'p_offset': offset,
    });
    return List<Map<String, dynamic>>.from(result as List);
  }

  // Fetch en batch de likes y guardados para una lista de posts.
  // Reemplaza N*3 queries por 2 queries al cargar el feed.
  Future<({Set<String> likedIds, Set<String> savedIds})> batchGetLikedAndSaved(
    List<String> postIds,
  ) async {
    final uid = _uid;
    if (uid == null || postIds.isEmpty) {
      return (likedIds: <String>{}, savedIds: <String>{});
    }
    final results = await Future.wait([
      _client.from('likes').select('post_id').eq('user_id', uid).inFilter('post_id', postIds),
      _client.from('saved_posts').select('post_id').eq('user_id', uid).inFilter('post_id', postIds),
    ]);
    final likedIds = (results[0] as List).map((r) => r['post_id'] as String).toSet();
    final savedIds = (results[1] as List).map((r) => r['post_id'] as String).toSet();
    return (likedIds: likedIds, savedIds: savedIds);
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
        : await VideoCompressor.compress(file);
    // El ext se deriva del archivo real: jpg tras comprimir imagen, mp4 tras
    // comprimir video, o el original si la compresión hizo fallback.
    final uploadExt = fileToUpload.path.split('.').last.toLowerCase();
    // Sufijo aleatorio para evitar colisiones al subir varias imágenes del
    // carrusel en el mismo milisegundo.
    final rand = Random().nextInt(0x7fffffff).toRadixString(36);
    final path =
        '$uid/${DateTime.now().millisecondsSinceEpoch}_$rand.$uploadExt';
    await _client.storage.from('posts').upload(
      path,
      fileToUpload,
      fileOptions: FileOptions(contentType: _contentTypeFor(uploadExt)),
    );
    return _client.storage.from('posts').getPublicUrl(path);
  }

  // Crea un post en Supabase (un solo media)
  Future<void> createPost({
    required String mediaUrl,
    required String mediaType,   // 'image' o 'video'
    required String caption,
  }) async {
    await createPostWithMedia(
      media: [(url: mediaUrl, type: mediaType)],
      caption: caption,
    );
  }

  /// Crea un post con uno o varios media (carrusel).
  /// El primer item queda como portada en posts.media_url/media_type para
  /// mantener compatibilidad con feed/grid; todos los items se guardan en
  /// post_media en orden. Si la inserción del carrusel falla, el post sigue
  /// existiendo como single (la portada) — nunca queda a medias sin imagen.
  Future<void> createPostWithMedia({
    required List<({String url, String type})> media,
    required String caption,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('No hay usuario autenticado');
    if (media.isEmpty) throw Exception('Debes seleccionar al menos una imagen.');
    if (media.length > maxCarouselImages) {
      throw Exception('Máximo $maxCarouselImages imágenes por publicación.');
    }

    final cover = media.first;
    final inserted = await _client.from('posts').insert({
      'user_id': uid,
      'media_url': cover.url,
      'media_type': cover.type,
      'caption': caption,
    }).select('id').single();

    final postId = inserted['id'] as String;

    // Guardar todos los items (incluida la portada) en post_media en orden.
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < media.length; i++) {
      rows.add({
        'post_id': postId,
        'media_url': media[i].url,
        'media_type': media[i].type,
        'position': i,
      });
    }
    await _client.from('post_media').insert(rows);

    await BadgeService.instance.checkAndAwardBadges(uid, 'post_created');
  }

  // Posts del usuario actual
  Future<List<Map<String, dynamic>>> getUserPosts() async {
    final uid = _uid;
    if (uid == null) return [];
    final result = await _client
        .from('posts')
        .select('id, media_url, media_type, caption, likes_count, comments_count, created_at, post_media(media_url, media_type, position)')
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
      try {
        await _client.rpc('notify_like', params: {'p_post_id': postId});
      } catch (e) {
        if (kDebugMode) debugPrint('[PostService.toggleLike] notify_like error: $e');
      }
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
    try {
      await _client.rpc('notify_comment', params: {'p_post_id': postId});
    } catch (e) {
      if (kDebugMode) debugPrint('[PostService.addComment] notify_comment error: $e');
    }
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
        .select('post_id, posts(id, user_id, media_url, media_type, caption, likes_count, comments_count, created_at, post_media(media_url, media_type, position))')
        .eq('user_id', uid)
        .order('saved_at', ascending: false);
    final list = List<Map<String, dynamic>>.from(result);
    // Aplanar: devolver el contenido del post directamente
    return list
        .map((row) => row['posts'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  // Registra cuánto tiempo el usuario vio un post (señal de interés real).
  // Ignorado si < 1 segundo o si falla — no bloquea ningún flujo.
  Future<void> logPostView(String postId, int viewMs) async {
    final uid = _uid;
    if (uid == null || postId.isEmpty || viewMs < 1000) return;
    try {
      await _client.from('post_views').insert({
        'post_id': postId,
        'user_id': uid,
        'view_ms': viewMs,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[PostService.logPostView] error: $e');
    }
  }
}
