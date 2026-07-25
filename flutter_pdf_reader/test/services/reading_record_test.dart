import 'package:flutter_test/flutter_test.dart';
import 'package:all_pdf_reader/services/reading_record_service.dart';

void main() {
  group('ReadingRecord', () {
    test('should create instance with defaults', () {
      final record = ReadingRecord(filePath: '/test.pdf');
      expect(record.filePath, '/test.pdf');
      expect(record.page, 1);
      expect(record.totalPages, 0);
      expect(record.progress, 0);
    });

    test('progress should calculate correctly', () {
      final record = ReadingRecord(filePath: '/test.pdf', page: 5, totalPages: 10);
      expect(record.progress, 0.5);
    });

    test('toJson and fromJson should round-trip', () {
      final record = ReadingRecord(
        filePath: '/test.pdf',
        page: 42,
        totalPages: 100,
        lastRead: DateTime(2026, 7, 25, 12, 0, 0),
      );

      final json = record.toJson();
      expect(json['page'], 42);
      expect(json['totalPages'], 100);

      final restored = ReadingRecord.fromJson('/test.pdf', json);
      expect(restored.filePath, '/test.pdf');
      expect(restored.page, 42);
      expect(restored.totalPages, 100);
    });

    test('lastRead should default to now', () {
      final record = ReadingRecord(filePath: '/test.pdf');
      expect(record.lastRead.difference(DateTime.now()).inSeconds.abs(), lessThan(5));
    });
  });
}
