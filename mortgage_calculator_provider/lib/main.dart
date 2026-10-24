import 'dart:math';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(
      ChangeNotifierProvider(
          create: (_) =>
          MortgageProvider()..loadSavedMortgage(),
          child: const MortgageCalculator(),
      ),
  );
}

//Shared provider to store mortgage data shared by both screens
class MortgageProvider extends ChangeNotifier{
  Mortgage _mortgage = Mortgage(
      amount: 200000,
      interest: 5.0,
      years: 30);

  bool _isLoading = true;

  Mortgage get mortgage => _mortgage;
  bool get isLoading => _isLoading;

  Future<void> loadSavedMortgage() async{
    try{
      final preferences = await SharedPreferences.getInstance();

      _mortgage = Mortgage(
        amount: preferences.getDouble('loanAmount') ?? 200000,
        interest: preferences.getDouble('interestRate') ?? 5.0,
        years: preferences.getInt('loanYears') ?? 30,
      );
    }
    catch (_){
      //Default mortgage values if data can't load
    }
    _isLoading = false;
    notifyListeners();
  }
  Future<void> updateMortgage(Mortgage mortgage) async{
    _mortgage = mortgage;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble('loanAmount', mortgage.amount);
    await preferences.setDouble('interestRate', mortgage.interest);
    await preferences.setInt('loanYears', mortgage.years);
  }
}


//Mortgage Class to initialize the mortgage values to have decimals and years
//and to calculate the monthly and total payments
class Mortgage {
  double amount;
  double interest;
  int years;

  Mortgage({
    required this.amount,
    required this.interest,
    required this.years,
  });

  double monthlyPayments(){
    final monthlyRate = interest / 100 / 12;
    final numberOfPayments = years *12;

    if (numberOfPayments <= 0) return 0;
    if (monthlyRate == 0) return amount / numberOfPayments;

    final rateFactor = pow(1 + monthlyRate, numberOfPayments);
    return amount *
    (monthlyRate * rateFactor) / (rateFactor - 1);
  }

  double totalPayments(){
    return monthlyPayments() * years * 12;
  }
}


class MortgageCalculator extends StatelessWidget {
  const MortgageCalculator({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mortgage Calculator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Consumer<MortgageProvider>(
        builder: (context, mortgageProvider, child){
          if (mortgageProvider.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return const MyHomePage(title: 'Mortgage Calculator');
        },
      ),
    );
  }
}

//Home page 
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});



  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool acceptedTerms = false;

  void showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Terms and Conditions',),
          content: const Text('Terms accepted.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  //Calls from the Mortgage Provider instead of having initialized values here
  @override
  Widget build(BuildContext context) {
    final mortgage = context.watch<MortgageProvider>().mortgage;
    final monthly = mortgage.monthlyPayments();
    final total = mortgage.totalPayments();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Amount"),
                Text("\$${mortgage.amount.toStringAsFixed(2)}"),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              const Text("Years"),
              Text("${mortgage.years}"),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Interest Rate"),
                Text("${mortgage.interest.toStringAsFixed(2)}%"),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Monthly Payment"),
                Text("\$${monthly.toStringAsFixed(2)}"),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Payment"),
                Text("\$${total.toStringAsFixed(2)}"),
              ],
            ),

            const SizedBox(height: 20),

            CheckboxListTile(
              title: const Text(
                "Terms and Conditions",
              ),
              value: acceptedTerms,
              onChanged: (bool? value) {
                setState(() {
                  acceptedTerms = value ?? false;
                });

                if (acceptedTerms){
                  showTermsDialog();
                }
              },
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MortgageInputPage(),
                  ),
                );
              },
              child: const Text("Edit Mortgage"),
            ),
          ],
        ),
      ),
    );
  }
}

//Mortgage Input Page to edit the mortgage values
class MortgageInputPage extends StatefulWidget {
  const MortgageInputPage({super.key,});

  @override
  State<MortgageInputPage> createState() =>
      _MortgageInputPageState();
}

class _MortgageInputPageState extends State<MortgageInputPage> {
  late TextEditingController amountController;
  late TextEditingController yearsController;

  double selectedRate = 5.0;
  final List<double> rates = [];

  @override
  void initState() {
    super.initState();

    final mortgage = context.read<MortgageProvider>().mortgage;

    amountController = TextEditingController(
      text: mortgage.amount.toString(),
    );

    yearsController = TextEditingController(
      text: mortgage.years.toString(),
    );

    selectedRate = mortgage.interest;

    for (double rate = 2.0; rate <= 15.0; rate += 0.25) {
      rates.add(double.parse(rate.toStringAsFixed(2)));
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    yearsController.dispose();
    super.dispose();
  }

  Future<void> saveMortgage() async{
    final amount = double.tryParse(amountController.text);
    final years = int.tryParse(yearsController.text);

    if (amount == null|| amount <= 0 || years == null || years<= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount and loan term.'))
      );
      return;
    }

    final updatedMortgage = Mortgage(
      amount: amount,
      interest: selectedRate,
      years: years,
    );

    await context.read<MortgageProvider>().updateMortgage(updatedMortgage);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context){
    return  Scaffold(
      appBar: AppBar(
        title: const Text('Modify Mortgage')
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: yearsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Years',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Interest Rates',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: rates.length,
                itemBuilder: (context, index){
                  final rate = rates[index];

                  return ListTile(
                    title: Text('${rate.toStringAsFixed(2)}%'),
                    selected: selectedRate == rate,
                    onTap: () {
                      setState(() {
                        selectedRate = rate;
                      });
                    },
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: saveMortgage,
              child: const Text('Done'),
            ),
          ],
        )
      )
    );
  }
}