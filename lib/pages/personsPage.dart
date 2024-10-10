import 'package:flutter/material.dart';

class Personspage extends StatefulWidget {
  const Personspage({super.key});

  @override
  State<Personspage> createState() => _PersonspageState();
}

class _PersonspageState extends State<Personspage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Personspage'),
      ),
      body: Center(
        child: Text('Personspage'),
      ),
    );
  }
}
