import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageService {
  static const String _imagesFolderName = 'mood_diary_images';
  static ImageService? _instance;
  static ImageService get instance => _instance ??= ImageService._();
  ImageService._();

  final ImagePicker _picker = ImagePicker();
  Directory? _imagesDirectory;
  
  // 웹용 임시 이미지 스토리지 (메모리)
  final Map<String, Uint8List> _webImageStorage = {};

  Future<void> init() async {
    try {
      // 웹이 아닌 플랫폼에서만 디렉토리 초기화
      if (!kIsWeb) {
        final appDocDir = await getApplicationDocumentsDirectory();
        _imagesDirectory = Directory('${appDocDir.path}/$_imagesFolderName');
        
        if (!await _imagesDirectory!.exists()) {
          await _imagesDirectory!.create(recursive: true);
        }
      }
    } catch (e) {
      print('이미지 디렉토리 초기화 오류: $e');
    }
  }

  // 갤러리에서 이미지 선택
  Future<String?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        return await _saveImageToLocal(image);
      }
      return null;
    } catch (e) {
      print('갤러리 이미지 선택 오류: $e');
      return null;
    }
  }

  // 카메라로 사진 촬영
  Future<String?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        return await _saveImageToLocal(image);
      }
      return null;
    } catch (e) {
      print('카메라 이미지 촬영 오류: $e');
      return null;
    }
  }

  // 여러 이미지 선택
  Future<List<String>> pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
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

  // 이미지를 로컬에 저장
  Future<String?> _saveImageToLocal(XFile image) async {
    try {
      final String fileName = '${const Uuid().v4()}.jpg';
      
      if (kIsWeb) {
        // 웹에서는 메모리에 저장
        final bytes = await image.readAsBytes();
        _webImageStorage[fileName] = bytes;
        return fileName; // 웹에서는 파일명만 반환
      } else {
        // 모바일/데스크톱에서는 파일 시스템에 저장
        await init(); // 디렉토리 확인
        
        final String filePath = '${_imagesDirectory!.path}/$fileName';
        final File imageFile = File(image.path);
        final File savedFile = await imageFile.copy(filePath);
        
        return savedFile.path;
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
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                      Navigator.pop(context);
                      final imagePath = await pickImageFromGallery();
                      Navigator.pop(context, imagePath);
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
                      Navigator.pop(context);
                      final imagePath = await pickImageFromCamera();
                      Navigator.pop(context, imagePath);
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
} 