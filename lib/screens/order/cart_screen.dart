import 'package:flutter/material.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController phoneController = TextEditingController();

  String selectedTime = "Deliver Now";

  final List<String> deliveryTimes = [
    "Deliver Now",
    "30 Minutes",
    "1 Hour",
    "2 Hours",
    "3 Hours",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Cart"),
        centerTitle: true,
      ),

      body: ListView(
  padding: const EdgeInsets.all(16),
  children: [

    const Text(
      "🛒 Your Order",
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    ),

    const SizedBox(height: 20),

    Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Chicken & Chips",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "UGX 18,000",
              style: TextStyle(fontSize: 16),
            ),
             const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [

                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.remove_circle),
                    ),

                    const Text(
                      "2",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.add_circle),
                    ),

                  ],
                ),
                const SizedBox(height: 25),

                        const Text(
                          "Phone Number",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),

                        const SizedBox(height: 10),

                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: "Enter phone number",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                        ),   

                   const SizedBox(height: 20),

            const Text(
              "Delivery Time",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: selectedTime,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: deliveryTimes.map((time) {
                return DropdownMenuItem(
                  value: time,
                  child: Text(time),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedTime = value!;
                });
              },
            ),


            const SizedBox(height: 25),

Card(
  color: Colors.green.shade100,
  child: Padding(
    padding: const EdgeInsets.all(20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [

        Text(
          "TOTAL",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),

        Text(
          "UGX 36,000",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

      ],
    ),
  ),
),



       const SizedBox(height: 30),

SizedBox(
  width: double.infinity,
  height: 55,
  child: ElevatedButton(
    onPressed: () {
      // We'll connect this to Firebase later.
    },
    child: const Text(
      "PLACE ORDER",
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
),


          ],
        ),
      ),
    ),

  ],
),
      ),
    );
  }
}