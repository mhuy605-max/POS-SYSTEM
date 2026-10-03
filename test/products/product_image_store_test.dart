import 'dart:io';

import 'package:dakao_in_bill/features/products/product_image_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'imports a picked image into app-owned storage using a relative path',
    () async {
      final sourceRoot = await Directory.systemTemp.createTemp('dakao_source_');
      final appRoot = await Directory.systemTemp.createTemp('dakao_support_');
      addTearDown(() async {
        await sourceRoot.delete(recursive: true);
        await appRoot.delete(recursive: true);
      });
      final source = File('${sourceRoot.path}${Platform.pathSeparator}món.JPG');
      await source.writeAsBytes([1, 2, 3, 4]);

      final store = ProductImageStore(appRoot);
      final relativePath = await store.importFile(source);

      expect(relativePath, startsWith('product-images/'));
      expect(relativePath, endsWith('.jpg'));
      expect(relativePath, isNot(contains(sourceRoot.path)));
      expect(await store.resolve(relativePath).readAsBytes(), [1, 2, 3, 4]);
    },
  );
}
