import 'package:flutter_test/flutter_test.dart';
import 'package:all_pdf_reader/main.dart';

void main() {
  testWidgets('App should render home page', (WidgetTester tester) async {
    await tester.pumpWidget(const AllPdfReaderApp());
    expect(find.text('All PDF Reader'), findsOneWidget);
    expect(find.text('打开 PDF 文件'), findsOneWidget);
  });
}
