import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:visit_card_scanner/pages/contacts.dart';
import 'package:visit_card_scanner/pages/scanner.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // include the dot!
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: const TabBarView(children: [ContactPage(), AddContactScreen()]),

          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFDBDBDB), width: 1),
              ),
            ),
            child: TabBar(
              tabs: [
                Tab(text: 'Contacts', icon: Icon(Icons.person)),
                Tab(
                  text: 'Scanner une carte',
                  icon: Icon(Icons.document_scanner_outlined),
                ),
              ],
              labelColor: Color(0xFF7D49FF),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF7D49FF),
            ),
          ),
        ),
      ),
      navigatorObservers: [routeObserver],
    );
  }
}
