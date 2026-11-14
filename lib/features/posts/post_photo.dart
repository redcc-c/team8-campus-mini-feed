import 'package:flutter/material.dart';

import '../../core/models.dart';

int postPhotoCount(FeedPost post, {required bool showSample}) =>
    post.photos.isNotEmpty
    ? post.photos.length
    : (showSample && post.photoAsset != null ? 1 : 0);

Widget postPhoto(
  FeedPost post,
  int index, {
  double? width,
  double? height,
  required BoxFit fit,
}) => post.photos.isNotEmpty
    ? Image.memory(post.photos[index], width: width, height: height, fit: fit)
    : Image.asset(post.photoAsset!, width: width, height: height, fit: fit);
