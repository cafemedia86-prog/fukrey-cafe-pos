import 'package:flutter/material.dart';

class SafeImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const SafeImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty || !url!.startsWith('http')) {
      return _Placeholder(width: width, height: height, borderRadius: borderRadius);
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.network(
        url!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _Placeholder(width: width, height: height, borderRadius: borderRadius);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const _Placeholder({this.width, this.height, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: borderRadius ?? BorderRadius.zero,
      ),
      child: Icon(
        Icons.fastfood,
        color: Colors.orange[200],
        size: (width != null && width! < 100) ? 30 : 50,
      ),
    );
  }
}
