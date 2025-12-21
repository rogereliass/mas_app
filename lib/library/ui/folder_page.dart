// TODO: Implement folder page UI
import 'package:flutter/material.dart';

class FolderPage extends StatelessWidget {
  final String? folderId;
  final String? folderName;

  const FolderPage({
    Key? key,
    this.folderId,
    this.folderName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(folderName ?? 'Folder'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Folder ID: ${folderId ?? "N/A"}'),
            SizedBox(height: 16),
            Text('Folder Name: ${folderName ?? "N/A"}'),
          ],
        ),
      ),
    );
  }
}