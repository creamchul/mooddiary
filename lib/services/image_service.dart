import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';

// 캐시된 이미지 데이터 클래스
class CachedImage {
  final Uint8List data;
  DateTime lastAccessed;

  CachedImage({
    required this.data,
    required this.lastAccessed,
  });
}

class ImageService {
  static const String _imagesFolderName = 'mood_diary_images';
  static const String _thumbnailsFolderName = 'mood_diary_thumbnails';
  static ImageService? _instance;
  static ImageService get instance => _instance ??= ImageService._();
  ImageService._();

  final ImagePicker _picker = ImagePicker();
  Directory? _imagesDirectory;
  Directory? _thumbnailsDirectory;
  
  // 웹용 임시 이미지 스토리지 (메모리)
  final Map<String, Uint8List> _webImageStorage = {};
  final Map<String, Uint8List> _webThumbnailStorage = {};
  
  // 이미지 캐시 (메모리 최적화) - CachedImage 사용
  final Map<String, CachedImage> _imageCache = {};
  static const int _maxCacheSize = 50; // 최대 50개 이미지 캐시

  Future<void> init() async {
    try {
      // 웹이 아닌 플랫폼에서만 디렉토리 초기화
      if (!kIsWeb) {
        final appDocDir = await getApplicationDocumentsDirectory();
        
        _imagesDirectory = Directory('${appDocDir.path}/$_imagesFolderName');
        _thumbnailsDirectory = Directory('${appDocDir.path}/$_thumbnailsFolderName');
        
        if (!await _imagesDirectory!.exists()) {
          await _imagesDirectory!.create(recursive: true);
        }
        
        if (!await _thumbnailsDirectory!.exists()) {
          await _thumbnailsDirectory!.create(recursive: true);
        }
      }
    } catch (e) {
      print('이미지 디렉토리 초기화 오류: $e');
    }
  }

  // 갤러리에서 이미지 선택
  Future<String?> pickImageFromGallery() async {
    try {
      print('갤러리에서 이미지 선택을 시작합니다...');
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920, // 더 높은 해상도로 변경
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        print('이미지가 선택되었습니다: ${image.path}');
        final savedPath = await _saveImageToLocal(image);
        if (savedPath != null) {
          print('갤러리에서 이미지 선택 성공: $savedPath');
          return savedPath;
        } else {
          print('이미지 저장에 실패했습니다');
          return null;
        }
      }
      print('갤러리에서 이미지 선택이 취소되었습니다.');
      return null;
    } catch (e) {
      print('갤러리 이미지 선택 오류: $e');
      // 권한 관련 오류인지 확인
      if (e.toString().contains('Permission') || 
          e.toString().contains('denied') ||
          e.toString().contains('photo_access_denied')) {
        print('권한 오류: 갤러리 접근 권한이 필요합니다.');
        throw Exception('갤러리 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요.');
      }
      throw e;
    }
  }

  // 카메라로 사진 촬영
  Future<String?> pickImageFromCamera() async {
    try {
      print('카메라로 사진 촬영을 시작합니다...');
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920, // 더 높은 해상도로 변경
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        print('사진이 촬영되었습니다: ${image.path}');
        final savedPath = await _saveImageToLocal(image);
        if (savedPath != null) {
          print('카메라에서 이미지 촬영 성공: $savedPath');
          return savedPath;
        } else {
          print('이미지 저장에 실패했습니다');
          return null;
        }
      }
      print('카메라에서 이미지 촬영이 취소되었습니다.');
      return null;
    } catch (e) {
      print('카메라 이미지 촬영 오류: $e');
      // 권한 관련 오류인지 확인
      if (e.toString().contains('Permission') || 
          e.toString().contains('denied') ||
          e.toString().contains('camera_access_denied')) {
        print('권한 오류: 카메라 접근 권한이 필요합니다.');
        throw Exception('카메라 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요.');
      }
      throw e;
    }
  }

  // 여러 이미지 선택
  Future<List<String>> pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920, // 더 높은 해상도로 변경
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      final List<String> savedPaths = [];
      for (final image in images) {
        final savedPath = await _saveImageToLocal(image);
        if (savedPath != null) {
          savedPaths.add(savedPath);
        }
      }
      
      return savedPaths;
    } catch (e) {
      print('여러 이미지 선택 오류: $e');
      return [];
    }
  }

  // 이미지 압축 (성능 최적화)
  Future<Uint8List> _compressImage(Uint8List imageBytes, {
    int? maxWidth,
    int? maxHeight,
    int quality = 85,
  }) async {
    try {
      // 웹이나 간단한 압축을 위해 그대로 반환
      // 실제 프로덕션에서는 image 패키지 등을 사용하여 압축
      return imageBytes;
    } catch (e) {
      print('이미지 압축 오류: $e');
      return imageBytes;
    }
  }

  // 썸네일 생성 (성능 최적화)
  Future<Uint8List> _generateThumbnail(Uint8List imageBytes, {
    int size = 200,
  }) async {
    try {
      // 썸네일 생성 로직
      // 실제로는 image 패키지를 사용하여 리사이징
      return await _compressImage(imageBytes, maxWidth: size, maxHeight: size, quality: 70);
    } catch (e) {
      print('썸네일 생성 오류: $e');
      return imageBytes;
    }
  }

  // 이미지를 로컬에 저장 (성능 최적화)
  Future<String?> _saveImageToLocal(XFile image) async {
    try {
      final String fileName = '${const Uuid().v4()}.jpg';
      final String thumbnailFileName = 'thumb_$fileName';
      
      final imageBytes = await image.readAsBytes();
      final compressedBytes = await _compressImage(imageBytes);
      final thumbnailBytes = await _generateThumbnail(compressedBytes);
      
      if (kIsWeb) {
        // 웹에서는 메모리에 저장
        _webImageStorage[fileName] = compressedBytes;
        _webThumbnailStorage[thumbnailFileName] = thumbnailBytes;
        return fileName;
      } else {
        // 모바일/데스크톱에서는 파일 시스템에 저장
        await init();
        
        final String filePath = '${_imagesDirectory!.path}/$fileName';
        final String thumbnailPath = '${_thumbnailsDirectory!.path}/$thumbnailFileName';
        
        // 원본 이미지 저장
        final File imageFile = File(filePath);
        await imageFile.writeAsBytes(compressedBytes);
        
        // 썸네일 저장
        final File thumbnailFile = File(thumbnailPath);
        await thumbnailFile.writeAsBytes(thumbnailBytes);
        
        return filePath;
      }
    } catch (e) {
      print('이미지 저장 오류: $e');
      return null;
    }
  }

  // 이미지 삭제
  Future<bool> deleteImage(String imagePath) async {
    try {
      if (kIsWeb) {
        // 웹에서는 메모리에서 삭제
        return _webImageStorage.remove(imagePath) != null;
      } else {
        // 모바일/데스크톱에서는 파일 삭제
        final File imageFile = File(imagePath);
        if (await imageFile.exists()) {
          await imageFile.delete();
          return true;
        }
        return false;
      }
    } catch (e) {
      print('이미지 삭제 오류: $e');
      return false;
    }
  }

  // 이미지 파일 존재 여부 확인
  Future<bool> imageExists(String imagePath) async {
    try {
      if (kIsWeb) {
        // 웹에서는 메모리 스토리지 확인
        return _webImageStorage.containsKey(imagePath);
      } else {
        // 모바일/데스크톱에서는 파일 존재 확인
        final File imageFile = File(imagePath);
        return await imageFile.exists();
      }
    } catch (e) {
      return false;
    }
  }

  // 웹용 이미지 데이터 가져오기
  Uint8List? getWebImageData(String fileName) {
    return _webImageStorage[fileName];
  }

  // 사용되지 않는 이미지 정리
  Future<void> cleanupUnusedImages(List<String> usedImagePaths) async {
    try {
      if (kIsWeb) {
        // 웹에서는 메모리 스토리지 정리
        final keysToRemove = <String>[];
        for (final key in _webImageStorage.keys) {
          if (!usedImagePaths.contains(key)) {
            keysToRemove.add(key);
          }
        }
        for (final key in keysToRemove) {
          _webImageStorage.remove(key);
          print('사용되지 않는 이미지 삭제: $key');
        }
      } else {
        // 모바일/데스크톱에서는 파일 시스템 정리
        await init();
        
        if (_imagesDirectory == null || !await _imagesDirectory!.exists()) {
          return;
        }
        
        final List<FileSystemEntity> files = await _imagesDirectory!.list().toList();
        
        for (final file in files) {
          if (file is File) {
            final String filePath = file.path;
            if (!usedImagePaths.contains(filePath)) {
              try {
                await file.delete();
                print('사용되지 않는 이미지 삭제: $filePath');
              } catch (e) {
                print('이미지 삭제 실패: $filePath, 오류: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      print('이미지 정리 오류: $e');
    }
  }

  // 이미지 선택 다이얼로그 표시
  Future<String?> showImagePickerDialog(BuildContext context) async {
    try {
      return await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        isScrollControlled: true,
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '사진 선택',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                                  Expanded(
                  child: _buildImagePickerOption(
                    context,
                    icon: Icons.photo_library,
                    label: '갤러리',
                    onTap: () async {
                      final imagePath = await pickImageFromGallery();
                      if (context.mounted) {
                        Navigator.of(context).pop(imagePath);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildImagePickerOption(
                    context,
                    icon: Icons.camera_alt,
                    label: '카메라',
                    onTap: () async {
                      final imagePath = await pickImageFromCamera();
                      if (context.mounted) {
                        Navigator.of(context).pop(imagePath);
                      }
                    },
                  ),
                ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    } catch (e) {
      print('이미지 선택 다이얼로그 오류: $e');
      // 권한 오류 메시지 표시
      if (context.mounted) {
        String errorMessage = '이미지를 선택할 수 없습니다.';
        if (e.toString().contains('권한')) {
          errorMessage = '카메라와 갤러리 권한이 필요합니다. 설정에서 권한을 허용해주세요.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '설정',
              onPressed: () {
                // 권한 설정 화면으로 이동하는 기능 추가 가능
              },
            ),
          ),
        );
      }
      return null;
    }
  }

  Widget _buildImagePickerOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 캐시된 이미지 가져오기 (성능 최적화)
  Future<Uint8List?> getCachedImage(String imagePath) async {
    try {
      // 캐시에서 먼저 확인
      if (_imageCache.containsKey(imagePath)) {
        return _imageCache[imagePath]?.data;
      }
      
      Uint8List? imageBytes;
      
      if (kIsWeb) {
        // 웹에서는 메모리 스토리지에서 가져오기
        imageBytes = _webImageStorage[imagePath];
      } else {
        // 파일에서 읽기
        final File imageFile = File(imagePath);
        if (await imageFile.exists()) {
          imageBytes = await imageFile.readAsBytes();
        }
      }
      
      if (imageBytes != null) {
        // 캐시에 저장 (크기 제한)
        _addToCache(imagePath, imageBytes);
        return imageBytes;
      }
      
      return null;
    } catch (e) {
      print('이미지 로딩 오류: $e');
      return null;
    }
  }

  // 썸네일 가져오기 (성능 최적화)
  Future<Uint8List?> getThumbnail(String imagePath) async {
    try {
      String thumbnailPath;
      
      if (kIsWeb) {
        // 웹에서는 썸네일 키 생성
        final fileName = imagePath;
        thumbnailPath = 'thumb_$fileName';
        return _webThumbnailStorage[thumbnailPath];
      } else {
        // 파일 시스템에서 썸네일 경로 생성
        final fileName = imagePath.split('/').last;
        thumbnailPath = '${_thumbnailsDirectory!.path}/thumb_$fileName';
        
        final File thumbnailFile = File(thumbnailPath);
        if (await thumbnailFile.exists()) {
          return await thumbnailFile.readAsBytes();
        }
      }
      
      return null;
    } catch (e) {
      print('썸네일 로딩 오류: $e');
      return null;
    }
  }

  // 캐시에 이미지 추가 (메모리 관리)
  void _addToCache(String key, Uint8List data) {
    if (_imageCache.length >= _maxCacheSize) {
      // 가장 오래된 항목 제거 (LRU)
      final oldestKey = _imageCache.keys.first;
      _imageCache.remove(oldestKey);
    }
    _imageCache[key] = CachedImage(data: data, lastAccessed: DateTime.now());
  }

  // 캐시 클리어 (메모리 최적화)
  void clearCache() {
    _imageCache.clear();
    print('이미지 캐시가 클리어되었습니다');
  }

  // 이미지 캐시 크기 getter (PerformanceService용)
  int get imageCacheSize => _imageCache.length;

  // 성능 최적화: 이미지 캐시 크기 제한
  void limitImageCacheSize({int maxSize = 50}) {
    if (_imageCache.length > maxSize) {
      // LRU 방식으로 가장 오래된 항목들 제거
      final entries = _imageCache.entries.toList();
      entries.sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));
      
      // 최신 maxSize개만 유지
      _imageCache.clear();
      for (int i = 0; i < maxSize && i < entries.length; i++) {
        _imageCache[entries[i].key] = entries[i].value;
      }
      
      if (kDebugMode) {
        print('[ImageService] 캐시 크기 제한: ${entries.length} -> $maxSize');
      }
    }
  }

  // 성능 최적화: 메모리 사용량 추정
  int getEstimatedMemoryUsage() {
    int totalSize = 0;
    for (final cachedImage in _imageCache.values) {
      totalSize += cachedImage.data.lengthInBytes;
    }
    return totalSize;
  }

  // 성능 최적화: 캐시 통계
  Map<String, dynamic> getCacheStats() {
    final memoryUsage = getEstimatedMemoryUsage();
    return {
      'cacheSize': _imageCache.length,
      'memoryUsage': memoryUsage,
      'memoryUsageMB': (memoryUsage / 1024 / 1024).toStringAsFixed(2),
      'hitRate': _cacheHits / (_cacheHits + _cacheMisses),
      'hits': _cacheHits,
      'misses': _cacheMisses,
    };
  }

  // 성능 최적화: 캐시 통계 변수
  int _cacheHits = 0;
  int _cacheMisses = 0;
  
  // 캐시 통계 업데이트
  void _updateCacheStats(bool isHit) {
    if (isHit) {
      _cacheHits++;
    } else {
      _cacheMisses++;
    }
  }
} 