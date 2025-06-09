import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../services/image_service.dart';
import '../constants/app_colors.dart';

class OptimizedImageWidget extends StatefulWidget {
  final String imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool useThumbnail;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedImageWidget({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.useThumbnail = false,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<OptimizedImageWidget> createState() => _OptimizedImageWidgetState();
}

class _OptimizedImageWidgetState extends State<OptimizedImageWidget>
    with AutomaticKeepAliveClientMixin {
  Uint8List? _imageData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(OptimizedImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath ||
        oldWidget.useThumbnail != widget.useThumbnail) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _imageData = null;
    });

    try {
      Uint8List? imageBytes;
      
      if (widget.useThumbnail) {
        // 썸네일 로딩 시도
        imageBytes = await ImageService.instance.getThumbnail(widget.imagePath);
      }
      
      // 썸네일이 없거나 원본 이미지 요청시 원본 로딩
      imageBytes ??= await ImageService.instance.getCachedImage(widget.imagePath);
      
      if (mounted) {
        setState(() {
          _imageData = imageBytes;
          _isLoading = false;
          _hasError = imageBytes == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoading) {
      return _buildPlaceholder();
    }
    
    if (_hasError || _imageData == null) {
      return _buildErrorWidget();
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        _imageData!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true, // 성능 최적화
        cacheWidth: widget.width?.toInt(),
        cacheHeight: widget.height?.toInt(),
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ??
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        );
  }

  Widget _buildErrorWidget() {
    return widget.errorWidget ??
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.broken_image,
            color: Colors.grey[600],
            size: 32,
          ),
        );
  }
}

// 이미지 그리드용 최적화된 위젯
class OptimizedImageGrid extends StatelessWidget {
  final List<String> imagePaths;
  final int crossAxisCount;
  final double childAspectRatio;
  final double spacing;
  final Function(String)? onImageTap;

  const OptimizedImageGrid({
    super.key,
    required this.imagePaths,
    this.crossAxisCount = 3,
    this.childAspectRatio = 1.0,
    this.spacing = 8.0,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: imagePaths.length,
      itemBuilder: (context, index) {
        final imagePath = imagePaths[index];
        return GestureDetector(
          onTap: () => onImageTap?.call(imagePath),
          child: OptimizedImageWidget(
            imagePath: imagePath,
            useThumbnail: true, // 그리드에서는 썸네일 사용
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}

// 리스트뷰용 최적화된 이미지 위젯
class OptimizedListImage extends StatelessWidget {
  final String imagePath;
  final double size;
  final Function()? onTap;

  const OptimizedListImage({
    super.key,
    required this.imagePath,
    this.size = 60,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: OptimizedImageWidget(
          imagePath: imagePath,
          width: size,
          height: size,
          useThumbnail: true, // 리스트에서는 썸네일 사용
          fit: BoxFit.cover,
        ),
      ),
    );
  }
} 