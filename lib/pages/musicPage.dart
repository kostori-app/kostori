import 'package:flutter/material.dart';

class Musicpage extends StatefulWidget {
  const Musicpage({super.key});

  @override
  State<Musicpage> createState() => _MusicpageState();
}

class _MusicpageState extends State<Musicpage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Musicpage'),
      ),
      body: Center(
        child: Text('Musicpage'),
      ),
    );
  }
}
