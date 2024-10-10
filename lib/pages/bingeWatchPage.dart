import 'package:flutter/material.dart';

class Bingewatchpage extends StatefulWidget {
  const Bingewatchpage({super.key});

  @override
  State<Bingewatchpage> createState() => _BingewatchpageState();
}

class _BingewatchpageState extends State<Bingewatchpage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BingeWatchPage'),
      ),
      body: Center(
        child: Text('BingeWatchPage'),
      ),
    );
  }
}
