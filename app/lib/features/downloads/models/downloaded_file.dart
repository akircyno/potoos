class DownloadedFile {
  const DownloadedFile({
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
    required this.expectedSizeBytes,
    required this.savedPath,
  });

  final String filename;
  final String mimeType;
  final int sizeBytes;
  final int expectedSizeBytes;
  final String savedPath;

  bool get sizeMatchesExpected =>
      expectedSizeBytes <= 0 || sizeBytes == expectedSizeBytes;
}
