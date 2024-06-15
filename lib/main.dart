import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAgJlzJnaRw740cBxQYaoznWe6NGERXp2EY",
      authDomain: "detection-8ee79.firebaseapp.com",
      projectId: "detection-8ee79",
      storageBucket: "detection-8ee79.appspot.com",
      messagingSenderId: "222750764525",
      appId: "1:222750764525:web:55cd26e55961fee5fc0be4",
      measurementId: "G-V55DR4Y6LM",
    ),
  );

  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(title: 'VanaRaksha'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  String? _latestNotificationMessage;
  bool _openedFromNotification = false;
  Timer? _callTimer;
  AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        setState(() {
          _latestNotificationMessage = message.notification?.body;
          _openedFromNotification = true;
        });
        _showLocationNotification(message.data);
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      setState(() {
        _latestNotificationMessage = message.notification?.body;
      });
      if (!_openedFromNotification) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(message.notification!.title ?? ''),
            content: Text(message.notification!.body ?? ''),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _cancelCallTimer();
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
        _startCallTimer();
        _showLocationNotification(message.data);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      setState(() {
        _latestNotificationMessage = message.notification?.body;
        _openedFromNotification = true;
      });
      _showLocationNotification(message.data);
    });
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer(Duration(seconds: 10), () {
      _makePhoneCall('+918919941286');
    });
  }


  void _cancelCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  Future<void> sendNotification() async {
    try {
      const String serverEndpoint = 'https://your-backend-endpoint/send-notification';
      final response = await http.post(
        Uri.parse(serverEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': 'Incoming Call',
          'body': 'Tap to answer the call',
          'data': {'type': 'call_request'},
          'to': 'recipient_fcm_token',
        }),
      );

      if (response.statusCode == 200) {
        print('Notification sent successfully.');
      } else {
        print('Error sending notification: ${response.body}');
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  Future<String> getAddress(double latitude, double longitude) async {
    final apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'];
        if (results.isNotEmpty) {
          return results[0]['formatted_address'];
        }
      }
      throw 'No address found';
    } catch (e) {
      throw 'Error fetching address: $e';
    }
  }

  void _showLocationNotification(Map<String, dynamic> data) async {
    try {
      final double latitude = double.parse(data['latitude'].toString());
      final double longitude = double.parse(data['longitude'].toString());
      final address = await getAddress(latitude, longitude);

      final String notificationMessage = 'Fire detected in satellite image\nLocation: https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
      setState(() {
        _latestNotificationMessage = notificationMessage;
      });

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Location Notification'),
          content: Text('Location: $address'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openGoogleMaps(latitude, longitude);
              },
              child: Text('Open in Maps'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch(e) {
      print('Error showing location notification: $e');
    }
  }

  void _openGoogleMaps(double latitude, double longitude) async {
    final String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    if (await canLaunch(googleMapsUrl)) {
      await launch(googleMapsUrl);
    } else {
      throw 'Could not open Google Maps';
    }
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  void _makePhoneCall(String phoneNumber) async {
    try {
      bool? res = await FlutterPhoneDirectCaller.callNumber(phoneNumber);
      if (res != null && res) {
        print('Phone call successful!');
      } else {
        print('Failed to make phone call!');
      }
    } catch (e) {
      print('Error making phone call: $e');
      // Handle the error here (e.g., show a message to the user)
    }
  }

  void _displayNotification(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Location Notification'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Dispose of resources
    _callTimer?.cancel();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_latestNotificationMessage != null && !_openedFromNotification)
              Text(
                'Latest Notification: $_latestNotificationMessage',
                style: TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 16),
            Text(
              '$_counter',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                // Use actual coordinates from the notification if available
                if (_latestNotificationMessage != null) {
                  try {
                    final urlPattern = RegExp(r'Location: (https://www\.google\.com/maps/search/\?api=1&query=[^ ]+)');
                    final match = urlPattern.firstMatch(_latestNotificationMessage!);
                    if (match != null) {
                      final Uri uri = Uri.parse(match.group(1)!);
                      final query = uri.queryParameters['query'];
                      if (query != null) {
                        final coords = query.split(',');
                        final double latitude = double.tryParse(coords[0]) ?? 0;
                        final double longitude = double.tryParse(coords[1]) ?? 0;
                        if (latitude != 0 && longitude != 0) {
                          _openGoogleMaps(latitude, longitude);
                        }
                      }
                    }
                  } catch (e) {
                    print('Error parsing coordinates: $e');
                    _openGoogleMaps(-59.03238, 51.85132); // Default coordinates
                  }
                } else {
                  _openGoogleMaps(-59.03238, 51.85132); // Default coordinates
                }
              },
              child: Text(
                'Open Google Maps',
                style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Make a phone call
                _makePhoneCall('+919059455770');
              },
              child: Text('Make Phone Call'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}