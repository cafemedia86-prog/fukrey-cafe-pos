import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class HomeShimmer extends StatelessWidget {
  const HomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 50),
          const ShimmerLoader(width: 250, height: 35),
          const SizedBox(height: 10),
          const ShimmerLoader(width: 200, height: 20),
          const SizedBox(height: 30),
          const ShimmerLoader(width: double.infinity, height: 50, borderRadius: 15),
          const SizedBox(height: 40),
          const ShimmerLoader(width: 150, height: 25),
          const SizedBox(height: 20),
          const ShimmerLoader(width: double.infinity, height: 100, borderRadius: 20),
          const SizedBox(height: 16),
          const ShimmerLoader(width: double.infinity, height: 100, borderRadius: 20),
          const SizedBox(height: 16),
          const ShimmerLoader(width: double.infinity, height: 100, borderRadius: 20),
        ],
      ),
    );
  }
}
