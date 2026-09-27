import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gal/gal.dart';
import 'package:gal/src/gal_platform_interface.dart';
import 'package:vcloud/core/utils/gallery_saver.dart';

final class MockGalPlatform extends GalPlatform {
  bool hasAccessResult = true;
  bool requestAccessResult = true;
  bool putImageBytesCalled = false;
  Uint8List? savedBytes;
  String? savedName;
  Exception? throwOnPut;

  @override
  Future<bool> hasAccess({bool toAlbum = false}) async {
    return hasAccessResult;
  }

  @override
  Future<bool> requestAccess({bool toAlbum = false}) async {
    return requestAccessResult;
  }

  @override
  Future<void> putImageBytes(
    Uint8List bytes, {
    String? album,
    required String name,
  }) async {
    if (throwOnPut != null) {
      throw throwOnPut!;
    }
    putImageBytesCalled = true;
    savedBytes = bytes;
    savedName = name;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGalPlatform mockPlatform;
  late GalPlatform originalPlatform;

  setUp(() {
    originalPlatform = GalPlatform.instance;
    mockPlatform = MockGalPlatform();
    GalPlatform.instance = mockPlatform;
  });

  tearDown(() {
    GalPlatform.instance = originalPlatform;
  });

  group('GallerySaver Unit Tests', () {
    test('1. Ném ngoại lệ khi mảng bytes rỗng', () async {
      expect(
        () => GallerySaver.saveImage(
          bytes: Uint8List(0),
          fileName: 'test.jpg',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('2. Lưu ảnh thành công khi đã có quyền truy cập', () async {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      mockPlatform.hasAccessResult = true;

      final success = await GallerySaver.saveImage(
        bytes: dummyBytes,
        fileName: 'vcloud_image_12345.png',
      );

      expect(success, isTrue);
      expect(mockPlatform.putImageBytesCalled, isTrue);
      expect(mockPlatform.savedName, equals('vcloud_image_12345'));
      expect(mockPlatform.savedBytes, equals(dummyBytes));
    });

    test('3. Tự động xin quyền khi chưa có quyền truy cập', () async {
      final dummyBytes = Uint8List.fromList([10, 20, 30]);
      mockPlatform.hasAccessResult = false;
      mockPlatform.requestAccessResult = true;

      final success = await GallerySaver.saveImage(
        bytes: dummyBytes,
        fileName: 'report_photo.jpg',
      );

      expect(success, isTrue);
      expect(mockPlatform.putImageBytesCalled, isTrue);
      expect(mockPlatform.savedName, equals('report_photo'));
    });

    test('4. Báo lỗi rõ ràng khi người dùng từ chối cấp quyền', () async {
      final dummyBytes = Uint8List.fromList([10, 20, 30]);
      mockPlatform.hasAccessResult = false;
      mockPlatform.requestAccessResult = false;

      expect(
        () => GallerySaver.saveImage(
          bytes: dummyBytes,
          fileName: 'photo.jpg',
        ),
        throwsA(
          predicate((e) =>
              e is Exception &&
              e.toString().contains('chưa được cấp quyền truy cập Thư viện ảnh')),
        ),
      );
    });

    test('5. Xử lý GalException khi bộ nhớ thiết bị đầy', () async {
      final dummyBytes = Uint8List.fromList([10, 20, 30]);
      mockPlatform.hasAccessResult = true;
      mockPlatform.throwOnPut = GalException(
        type: GalExceptionType.notEnoughSpace,
        platformException: PlatformException(code: 'NOT_ENOUGH_SPACE'),
        stackTrace: StackTrace.empty,
      );

      expect(
        () => GallerySaver.saveImage(
          bytes: dummyBytes,
          fileName: 'photo.jpg',
        ),
        throwsA(
          predicate((e) =>
              e is Exception &&
              e.toString().contains('Bộ nhớ thiết bị không đủ dung lượng')),
        ),
      );
    });
  });
}
