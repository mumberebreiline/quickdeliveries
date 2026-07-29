import 'package:flutter/material.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.storefront, size: 56, color: Colors.deepPurple),
          const SizedBox(height: 16),
          const Text(
            'Quick Deliveries',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Quick Deliveries brings fresh, home-style food straight to '
            'you, wherever you are on Makerere University campus from '
            'your hall of residence to your lecture hall. No walking '
            'across campus on an empty stomach between classes.',
            style: TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 20),
          const Text(
            'Our Mission',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'To make good food genuinely accessible to every student and '
            'staff member on campus ordered in a couple of taps, '
            'delivered reliably, at a fair price.',
            style: TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 20),
          const Text(
            'How It Works',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Browse the menu, add what you like to your cart, and place '
            'your order no account required. Behind the scenes, orders '
            'are grouped and routed efficiently so our delivery team can '
            'get to you as quickly as possible, wherever on campus you '
            'happen to be.',
            style: TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Get in touch',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.email_outlined, color: Colors.deepPurple),
            title: Text('hello@quickdeliveries.example'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.phone_outlined, color: Colors.deepPurple),
            title: Text('+256 752329165'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.location_on_outlined, color: Colors.deepPurple),
            title: Text('Makerere University, Kampala, Uganda'),
          ),
        ],
      ),
    );
  }
}
