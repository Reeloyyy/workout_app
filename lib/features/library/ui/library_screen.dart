import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/import'),
        tooltip: 'Import',
        child: const Icon(Icons.add),
      ),
    );
  }
}
