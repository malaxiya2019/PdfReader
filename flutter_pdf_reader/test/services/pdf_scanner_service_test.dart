import 'package:flutter_test/flutter_test.dart';
import 'package:all_pdf_reader/models/pdf_file_info.dart';
import 'package:all_pdf_reader/services/pdf_scanner_service.dart';

void main() {
  group('PdfScannerService', () {
    group('sortFiles', () {
      final now = DateTime.now();
      final files = [
        PdfFileInfo(path: '/b.pdf', name: 'b.pdf', sizeInBytes: 200, lastModified: now.subtract(const Duration(hours: 1))),
        PdfFileInfo(path: '/a.pdf', name: 'a.pdf', sizeInBytes: 100, lastModified: now),
        PdfFileInfo(path: '/c.pdf', name: 'c.pdf', sizeInBytes: 300, lastModified: now.subtract(const Duration(hours: 2))),
      ];

      test('should sort by name ascending', () {
        final sorted = List<PdfFileInfo>.from(files);
        PdfScannerService.sortFiles(sorted, sortBy: SortBy.name, ascending: true);
        expect(sorted[0].name, 'a.pdf');
        expect(sorted[1].name, 'b.pdf');
        expect(sorted[2].name, 'c.pdf');
      });

      test('should sort by name descending', () {
        final sorted = List<PdfFileInfo>.from(files);
        PdfScannerService.sortFiles(sorted, sortBy: SortBy.name, ascending: false);
        expect(sorted[0].name, 'c.pdf');
        expect(sorted[1].name, 'b.pdf');
        expect(sorted[2].name, 'a.pdf');
      });

      test('should sort by size ascending', () {
        final sorted = List<PdfFileInfo>.from(files);
        PdfScannerService.sortFiles(sorted, sortBy: SortBy.size, ascending: true);
        expect(sorted[0].sizeInBytes, 100);
        expect(sorted[1].sizeInBytes, 200);
        expect(sorted[2].sizeInBytes, 300);
      });

      test('should sort by date descending (default)', () {
        final sorted = List<PdfFileInfo>.from(files);
        PdfScannerService.sortFiles(sorted, sortBy: SortBy.date, ascending: false);
        // newest first
        expect(sorted[0].lastModified.isAfter(sorted[1].lastModified), true);
      });
    });

    group('searchFiles', () {
      final files = [
        PdfFileInfo(path: '/a.pdf', name: 'report.pdf', sizeInBytes: 100, lastModified: DateTime.now()),
        PdfFileInfo(path: '/b.pdf', name: 'invoice.pdf', sizeInBytes: 200, lastModified: DateTime.now()),
        PdfFileInfo(path: '/c.pdf', name: 'book_chapter1.pdf', sizeInBytes: 300, lastModified: DateTime.now()),
      ];

      test('should return all files when query is empty', () {
        expect(PdfScannerService.searchFiles(files, '').length, 3);
      });

      test('should filter by file name', () {
        final result = PdfScannerService.searchFiles(files, 'report');
        expect(result.length, 1);
        expect(result[0].name, 'report.pdf');
      });

      test('should filter by path', () {
        final result = PdfScannerService.searchFiles(files, 'chapter');
        expect(result.length, 1);
        expect(result[0].name, 'book_chapter1.pdf');
      });

      test('should be case insensitive', () {
        final result = PdfScannerService.searchFiles(files, 'REPORT');
        expect(result.length, 1);
        expect(result[0].name, 'report.pdf');
      });

      test('should return empty list when no match', () {
        expect(PdfScannerService.searchFiles(files, 'nonexistent').length, 0);
      });
    });

    group('SortBy labels', () {
      test('should have Chinese labels', () {
        expect(SortBy.name.label, '文件名');
        expect(SortBy.size.label, '文件大小');
        expect(SortBy.date.label, '修改时间');
      });
    });
  });
}
