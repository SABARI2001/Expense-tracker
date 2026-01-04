import 'package:flutter/material.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade to Pro')),
      body: const Center(child: Text('Paywall Content')),
    );
  }
}
