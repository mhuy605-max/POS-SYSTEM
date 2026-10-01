import 'dart:io';

final class ProductImageStore {
  ProductImageStore(this.rootDirectory);

  static const directoryName = 'product-images';
  final Directory rootDirectory;

  Future<String> importFile(File source) async {
    if (!await source.exists()) {
      throw ArgumentError.value(
        source.path,
        'source',
        'Image file does not exist.',
      );
    }
    final extension = _safeExtension(source.path);
    final directory = Directory(
      '${rootDirectory.path}${Platform.pathSeparator}$directoryName',
    );
    await directory.create(recursive: true);
    var suffix = DateTime.now().microsecondsSinceEpoch;
    File target;
    do {
      target = File(
        '${directory.path}${Platform.pathSeparator}product_$suffix$extension',
      );
      suffix++;
    } while (await target.exists());
    await source.copy(target.path);
    return '$directoryName/${target.uri.pathSegments.last}';
  }

  File resolve(String relativePath) {
    final normalized = relativePath.replaceAll('/', Platform.pathSeparator);
    return File('${rootDirectory.path}${Platform.pathSeparator}$normalized');
  }
}

String _safeExtension(String path) {
  final fileName = path.replaceAll('\\', '/').split('/').last;
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return '';
  final extension = fileName.substring(dot).toLowerCase();
  return RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(extension) ? extension : '';
}
