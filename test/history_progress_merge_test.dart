import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/foundation/anime_type.dart';

Progress _progress({
  String historyId = 'h1',
  int type = 7,
  int episode = 1,
  int road = 0,
  int progressInMilli = 0,
  bool isCompleted = false,
  DateTime? startTime,
  DateTime? endTime,
}) => Progress(
  historyId: historyId,
  type: AnimeType(type),
  episode: episode,
  road: road,
  progressInMilli: progressInMilli,
  isCompleted: isCompleted,
  startTime: startTime,
  endTime: endTime,
);

void main() {
  group('Progress 同步用序列化', () {
    test('json 往返', () {
      final p = _progress(
        progressInMilli: 12345,
        isCompleted: true,
        startTime: DateTime(2024, 5, 1, 10),
        endTime: DateTime(2024, 5, 1, 10, 24),
      );
      final back = Progress.fromJson(p.toJson());
      expect(back.historyId, 'h1');
      expect(back.type, AnimeType(7));
      expect(back.episode, 1);
      expect(back.road, 0);
      expect(back.progressInMilli, 12345);
      expect(back.isCompleted, isTrue);
      expect(back.startTime, DateTime(2024, 5, 1, 10));
      expect(back.endTime, DateTime(2024, 5, 1, 10, 24));
    });

    test('字段缺失时用默认值', () {
      final back = Progress.fromJson(const {});
      expect(back.historyId, '');
      expect(back.type, AnimeType(0));
      expect(back.progressInMilli, 0);
      expect(back.isCompleted, isFalse);
      expect(back.startTime, isNull);
      expect(back.endTime, isNull);
    });

    test('key 由 type/historyId/episode/road 组成', () {
      expect(_progress().key, '7|h1|1|0');
      expect(_progress(episode: 3, road: 2).key, '7|h1|3|2');
    });
  });

  group('Progress.isNewerThan', () {
    test('结束时间更晚者更新', () {
      final older = _progress(endTime: DateTime(2024, 5, 1));
      final newer = _progress(endTime: DateTime(2024, 5, 2));
      expect(newer.isNewerThan(older), isTrue);
      expect(older.isNewerThan(newer), isFalse);
    });

    test('只有一方有结束时间时，有的一方更新', () {
      final withEnd = _progress(endTime: DateTime(2024, 5, 1));
      final without = _progress(progressInMilli: 99999);
      expect(withEnd.isNewerThan(without), isTrue);
      expect(without.isNewerThan(withEnd), isFalse);
    });

    test('都没有结束时间时观看进度更大者更新', () {
      final more = _progress(progressInMilli: 5000);
      final less = _progress(progressInMilli: 100);
      expect(more.isNewerThan(less), isTrue);
      expect(less.isNewerThan(more), isFalse);
    });

    test('结束时间相同则比较观看进度', () {
      final t = DateTime(2024, 5, 1);
      final more = _progress(progressInMilli: 5000, endTime: t);
      final less = _progress(progressInMilli: 100, endTime: t);
      expect(more.isNewerThan(less), isTrue);
      expect(less.isNewerThan(more), isFalse);
    });
  });
}
