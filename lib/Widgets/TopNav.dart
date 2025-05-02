import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TopNav extends StatefulWidget {
  const TopNav({super.key});

  @override
  State<TopNav> createState() => _TopNavState();
}

class _TopNavState extends State<TopNav> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      color: Colors.grey.shade50,
    );
  }
}
