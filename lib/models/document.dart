class Document {
  final String id;
  final String filename;
  final int totalPages;
  final String? createdAt;
  final List<PageData> pages;

  Document({
    required this.id,
    required this.filename,
    required this.totalPages,
    this.createdAt,
    required this.pages,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'],
      filename: json['filename'],
      totalPages: json['total_pages'],
      createdAt: json['created_at'],
      pages: (json['pages'] as List)
          .map((p) => PageData.fromJson(p))
          .toList(),
    );
  }
}

class PageData {
  final int pageNumber;
  final String text;
  final List<String> imageIds;
  final Dimensions dimensions;

  PageData({
    required this.pageNumber,
    required this.text,
    required this.imageIds,
    required this.dimensions,
  });

  factory PageData.fromJson(Map<String, dynamic> json) {
    return PageData(
      pageNumber: json['page_number'],
      text: json['text'] ?? '',
      imageIds: List<String>.from(json['image_ids'] ?? []),
      dimensions: Dimensions.fromJson(json['dimensions']),
    );
  }
}

class Dimensions {
  final double width;
  final double height;

  Dimensions({required this.width, required this.height});

  factory Dimensions.fromJson(Map<String, dynamic> json) {
    return Dimensions(
      width: json['width'].toDouble(),
      height: json['height'].toDouble(),
    );
  }
}

class ImageData {
  final String id;
  final String data;
  final String extension;

  ImageData({
    required this.id,
    required this.data,
    required this.extension,
  });

  factory ImageData.fromJson(Map<String, dynamic> json) {
    return ImageData(
      id: json['id'],
      data: json['data'],
      extension: json['extension'],
    );
  }
}