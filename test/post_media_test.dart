import 'package:flutter_test/flutter_test.dart';
import 'package:gymgram_beta/services/post_service.dart';

void main() {
  group('PostService.mediaOf', () {
    test('lee el array `media` del feed RPC en orden', () {
      final post = {
        'media_url': 'https://x/cover.jpg',
        'media_type': 'image',
        'media': [
          {'media_url': 'https://x/0.jpg', 'media_type': 'image'},
          {'media_url': 'https://x/1.jpg', 'media_type': 'image'},
          {'media_url': 'https://x/2.jpg', 'media_type': 'image'},
        ],
      };
      final media = PostService.mediaOf(post);
      expect(media.length, 3);
      expect(media[0].url, 'https://x/0.jpg');
      expect(media[2].url, 'https://x/2.jpg');
      expect(media.every((m) => m.type == 'image'), isTrue);
    });

    test('ordena el embed `post_media` por position', () {
      final post = {
        'media_url': 'https://x/cover.jpg',
        'post_media': [
          {'media_url': 'https://x/2.jpg', 'media_type': 'image', 'position': 2},
          {'media_url': 'https://x/0.jpg', 'media_type': 'image', 'position': 0},
          {'media_url': 'https://x/1.jpg', 'media_type': 'image', 'position': 1},
        ],
      };
      final media = PostService.mediaOf(post);
      expect(media.map((m) => m.url).toList(), [
        'https://x/0.jpg',
        'https://x/1.jpg',
        'https://x/2.jpg',
      ]);
    });

    test('cae a media_url cuando no hay media ni post_media (post antiguo)', () {
      final post = {
        'media_url': 'https://x/old.jpg',
        'media_type': 'video',
      };
      final media = PostService.mediaOf(post);
      expect(media.length, 1);
      expect(media.first.url, 'https://x/old.jpg');
      expect(media.first.type, 'video');
    });

    test('media/post_media vacíos también caen a media_url', () {
      final post = {
        'media_url': 'https://x/single.jpg',
        'media': <dynamic>[],
        'post_media': <dynamic>[],
      };
      final media = PostService.mediaOf(post);
      expect(media.length, 1);
      expect(media.first.url, 'https://x/single.jpg');
    });

    test('siempre devuelve al menos un elemento aunque falte todo', () {
      final media = PostService.mediaOf(<String, dynamic>{});
      expect(media.length, 1);
      expect(media.first.type, 'image');
    });

    test('ignora entradas con url vacía pero conserva las válidas', () {
      final post = {
        'media': [
          {'media_url': '', 'media_type': 'image'},
          {'media_url': 'https://x/ok.jpg', 'media_type': 'image'},
        ],
      };
      final media = PostService.mediaOf(post);
      expect(media.length, 1);
      expect(media.first.url, 'https://x/ok.jpg');
    });

    test('el límite del carrusel es 10', () {
      expect(PostService.maxCarouselImages, 10);
    });
  });
}
