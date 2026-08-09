import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/community_photo_grid.dart';

void main() {
  group('cloudinaryPlayableVideoUrl', () {
    test('rewrites a raw 4K .mov to a w_1080 mp4', () {
      const raw =
          'https://res.cloudinary.com/djz0pypu1/video/upload/v1785604816/mrjzhpfzoh9ipqyvqykx.mov';
      expect(
        cloudinaryPlayableVideoUrl(raw),
        'https://res.cloudinary.com/djz0pypu1/video/upload/'
        'w_1080,q_auto/v1785604816/mrjzhpfzoh9ipqyvqykx.mp4',
      );
    });

    test('rewrites a raw .mp4 with query string', () {
      const raw =
          'https://res.cloudinary.com/djz0pypu1/video/upload/v1785863310/wa5x3utizc985kn8xvif.mp4?x=1';
      expect(
        cloudinaryPlayableVideoUrl(raw),
        'https://res.cloudinary.com/djz0pypu1/video/upload/'
        'w_1080,q_auto/v1785863310/wa5x3utizc985kn8xvif.mp4',
      );
    });

    test('leaves an already-transformed URL untouched', () {
      const transformed =
          'https://res.cloudinary.com/djz0pypu1/video/upload/'
          'w_1080,q_auto/v1785604816/mrjzhpfzoh9ipqyvqykx.mp4';
      expect(cloudinaryPlayableVideoUrl(transformed), transformed);
    });

    test('leaves a non-Cloudinary URL untouched', () {
      const other = 'https://cdn.example.com/videos/clip.mov';
      expect(cloudinaryPlayableVideoUrl(other), other);
    });

    test('leaves a Cloudinary image URL untouched', () {
      const img =
          'https://res.cloudinary.com/djz0pypu1/image/upload/v1785763295/llcqx2nqkokkrsucx7h1.jpg';
      expect(cloudinaryPlayableVideoUrl(img), img);
    });
  });
}
