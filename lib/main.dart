import 'package:flutter/material.dart';
import 'routes.dart';

void main() {
  runApp(const GymGramApp());
}

class GymGramApp extends StatelessWidget {
  const GymGramApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymGram',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      initialRoute: '/',
      routes: appRoutes,
    );
  }
}
