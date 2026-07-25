import 'package:flutter_test/flutter_test.dart';
import 'package:all_pdf_reader/models/pdf_file_info.dart';

void main() {
  group('PdfFileInfo', () {
    final now = DateTime(2026, 7, 25, 12, 0, 0);
    final yesterday = DateTime(2026, 7, 24, 12, 0, 0);

    test('should create instance with correct values', () {
      final file = PdfFileInfo(
        path: '/storage/emulated/0/Download/test.pdf',
        name: 'test.pdf',
        sizeInBytes: 1024 * 1024, // 1 MB
        lastModified: now,
      );

      expect(file.path, '/storage/emulated/0/Download/test.pdf');
      expect(file.name, 'test.pdf');
      expect(file.sizeInBytes, 1024 * 1024);
      expect(file.lastModified, now);
      expect(file.isFavorite, false);
    });

    test('sizeFormatted should return correct format', () {
      expect(
        PdfFileInfo(
          path: '/a.pdf', name: 'a.pdf', sizeInBytes: 500,
          lastModified: now,
        ).sizeFormatted,
        '500 B',
      );

      expect(
        PdfFileInfo(
          path: '/a.pdf', name: 'a.pdf', sizeInBytes: 1024,
          lastModified: now,
        ).sizeFormatted,
        '1.0 KB',
      );

      expect(
        PdfFileInfo(
          path: '/a.pdf', name: 'a.pdf', sizeInBytes: 2 * 1024 * 1024,
          lastModified: now,
        ).sizeFormatted,
        '2.0 MB',
      );

      expect(
        PdfFileInfo(
          path: '/a.pdf', name: 'a.pdf', sizeInBytes: 2 * 1024 * 1024 * 1024,
          lastModified: now,
        ).sizeFormatted,
        '2.0 GB',
      );
    });

    test('dateFormatted should return relative time', () {
      final justNow = DateTime.now();
      expect(
        PdfFileInfo(
          path: '/a.pdf', name: 'a.pdf', sizeInBytes: 100,
          lastModified: justNow,
        ).dateFormatted,
        '刚刚',
      );

      final anHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      final result1 = PdfFileInfo(
        path: '/a.pdf', name: 'a.pdf', sizeInBytes: 100,
        lastModified: anHourAgo,
      ).dateFormatted;
      expect(result1, '1 小时前');
    });

    test('folderName should extract parent directory', () {
      expect(
        PdfFileInfo(
          path: '/storage/emulated/0/Download/test.pdf',
          name: 'test.pdf', sizeInBytes: 100,
          lastModified: now,
        ).folderName,
        'Download',
      );

      expect(
        PdfFileInfo(
          path: '/test.pdf',
          name: 'test.pdf', sizeInBytes: 100,
          lastModified: now,
        ).folderName,
        '/',
      );
    });

    test('isFavorite should be mutable', () {
      final file = PdfFileInfo(
        path: '/a.pdf', name: 'a.pdf', sizeInBytes: 100,
        lastModified: now,
      );
      expect(file.isFavorite, false);

      file.isFavorite = true;
      expect(file.isFavorite, true);
    });
  });
}
