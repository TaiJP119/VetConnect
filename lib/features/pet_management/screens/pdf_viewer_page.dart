import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PDFViewerPage extends StatefulWidget {
  final String url;
  const PDFViewerPage({super.key, required this.url});

  @override
  State<PDFViewerPage> createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  String? localPath;

  @override
  void initState() {
    super.initState();
    loadPdf();
  }

  Future<void> loadPdf() async {
    final response = await http.get(Uri.parse(widget.url));
    final bytes = response.bodyBytes;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/temp.pdf');

    await file.writeAsBytes(bytes, flush: true);
    setState(() {
      localPath = file.path;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (localPath == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Loading PDF...")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("PDF Viewer")),
      body: PDFView(
        filePath: localPath!,
      ),
    );
  }
}
