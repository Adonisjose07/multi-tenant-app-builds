import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../services/queries.dart';
import '../home/home_screen.dart';

class RegisterDriverScreen extends StatefulWidget {
  const RegisterDriverScreen({super.key});

  @override
  State<RegisterDriverScreen> createState() => _RegisterDriverScreenState();
}

class _RegisterDriverScreenState extends State<RegisterDriverScreen> {
  final _plateController = TextEditingController();
  final _licenseController = TextEditingController();
  String _vehicleType = 'motorcycle';
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register as Driver")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Mutation(
          options: MutationOptions(
            document: gql(Queries.registerDriver),
            onCompleted: (data) {
              if (data != null) {
                Navigator.pushReplacement(
                  context, 
                  MaterialPageRoute(builder: (_) => const HomeScreen())
                );
              }
            },
            onError: (error) {
               ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error?.graphqlErrors.first.message ?? "Registration Failed"))
              );
            }
          ),
          builder: (RunMutation runMutation, QueryResult? result) {
            return Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _vehicleType,
                    items: ['motorcycle', 'bicycle', 'car', 'walking']
                        .map((type) => DropdownMenuItem(value: type, child: Text(type.toUpperCase())))
                        .toList(),
                    onChanged: (v) => setState(() => _vehicleType = v!),
                    decoration: const InputDecoration(labelText: "Vehicle Type"),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _plateController,
                    decoration: const InputDecoration(labelText: "Plate Number"),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _licenseController,
                    decoration: const InputDecoration(labelText: "License Number"),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 20),
                  if (result?.isLoading ?? false)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          runMutation({
                            'vehicleType': _vehicleType,
                            'plateNumber': _plateController.text.trim(),
                            'licenseNumber': _licenseController.text.trim(),
                          });
                        }
                      },
                      child: const Text("Register & Start"),
                    )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
