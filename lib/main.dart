import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'wildfire_handling.dart';
import 'safety_tips.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'emergency_kit_checklist.dart';
import 'fcm_token_hander.dart';



class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fire Safety App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmergencyKitChecklist(),
                  ),
                );
              },
              child: Text('Emergency Kit Checklist'),
            ),

          ],
        ),
      ),
    );
  }
}


void _sendLocationToEmergencyContacts(BuildContext context, String locationUrl) async {
  const List<String> emergencyContacts = [
    'tel:+918497920037',
    'tel:+9190594555770'
  ];

  for (String contact in emergencyContacts) {
    final Uri uri = Uri.parse('$contact?body=Fire reported at: $locationUrl');
    if (await canLaunch(uri.toString())) {
      await launch(uri.toString());
    } else {
      throw 'Could not launch $uri';
    }
  }

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Report Fire'),
      content: Text('Fire location sent to emergency contacts successfully!'),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('OK'),
        ),
      ],
    ),
  );
}

class GoogleMapPicker extends StatefulWidget {
  final Function(LatLng) onLocationPicked;

  GoogleMapPicker({required this.onLocationPicked});

  @override
  _GoogleMapPickerState createState() => _GoogleMapPickerState();
}

class _GoogleMapPickerState extends State<GoogleMapPicker> {
  LatLng _pickedLocation = LatLng(37.7749, -122.4194); // Default location

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pick a Location'),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: () {
              widget.onLocationPicked(_pickedLocation);
            },
          )
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _pickedLocation,
          zoom: 14.0,
        ),
        onTap: (LatLng location) {
          setState(() {
            _pickedLocation = location;
          });
        },
        markers: {
          Marker(
            markerId: MarkerId('pickedLocation'),
            position: _pickedLocation,
          ),
        },
      ),
    );
  }
}







void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAq0-RvJNDHOk2srKNnhqP5Ii3y9ziprzk",
      authDomain: "detect-2cdd9.firebaseapp.com",
      projectId: "detect-2cdd9",
      storageBucket: "detect-2cdd9.appspot.com",
      messagingSenderId: "583471575704",
      appId: "1:583471575704:android:eba2de02f98ca638e656ed",
      measurementId: "G-V55DR4Y6LM",

    ),
  );
  String? fcmToken = await FCMTokenHandler.getFCMToken();
  print('FCM Token: $fcmToken');
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}


Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
  // You can process the message here, e.g., showing a notification
}
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);



  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(title: 'VanaRaksha'),
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
  String? _latestNotificationMessage;
  bool _openedFromNotification = false;
  Timer? _callTimer;
  int _counter = 0;
  bool _notificationHandled = false;

  //late GoogleApiAvailability _gApi;

  @override
  void initState() {
    super.initState();
    //_gApi = GoogleApiAvailability();
    // _checkGooglePlayServices();


    FirebaseMessaging.instance.getInitialMessage().then((
        RemoteMessage? message) {
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
        _notificationHandled = false; // Reset notification handling flag
      });
      if (!_openedFromNotification) {
        _displayNotification(message.notification?.title ?? '',
            message.notification?.body ?? '');
        // Start the call timer only if the user doesn't respond to the notification
        if (!_notificationHandled) {
          _startCallTimer();
        }
        _showLocationNotification(message.data);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      setState(() {
        _latestNotificationMessage = message.notification?.body;
        _openedFromNotification = true;
        _notificationHandled = true; // Mark notification as handled
      });
      _showLocationNotification(message.data);
    });
  }

  void _handleMessage(RemoteMessage message) {
    setState(() {
      _latestNotificationMessage = message.notification?.body;
      _openedFromNotification = true;
      _notificationHandled = true;
    });
    _showLocationNotification(message.data);
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer(Duration(seconds: 10), () {
      if (!_notificationHandled) {
        _makePhoneCall('+919059455770');
      }
    });
  }

  // Function to retrieve and print the FCM token
  Future<void> _retrieveFCMToken() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    String? token = await messaging.getToken();
    if (token != null) {
      print("FCM Token: $token");

    }
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

      String locationType = 'default';
      if (address.contains('Forest') || address.contains('Park')) {
        locationType = 'forest_area';
      }


      final String notificationMessage = 'Fire detected in satellite image\nLocation: https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
      setState(() {
        _latestNotificationMessage = notificationMessage;
      });

      showDialog(
        context: context,
        builder: (_) =>
            AlertDialog(
              title: Text('Location Notification'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                ],
              ),
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
                    _cancelCallTimer(); // Cancel call timer when OK is pressed
                  },
                  child: Text('OK'),
                ),
              ],
            ),
      );
    } catch (e) {
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

  void _displayNotification(String title, String message) {
    showDialog(
      context: context,
      builder: (_) =>
          AlertDialog(
            title: Text(title),
            content: Text(
                'Wildfire is detected !!,Open the app to get the exact location'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  _notificationHandled = true; // Mark notification as handled
                  _cancelCallTimer(); // Cancel the call timer
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          ),
    );
  }


  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  /*@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_latestNotificationMessage != null && !_openedFromNotification)
                Card(
                  color: Colors.orange[50],
                  margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                  child: ListTile(
                    leading: Icon(Icons.notification_important, color: Colors.red),
                    title: Text(
                      'Latest Notification:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _latestNotificationMessage!,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
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
                      _openGoogleMaps( 44.427963, -110.588455); // Default coordinates
                    }
                  } else {
                    _openGoogleMaps( 44.427963, -110.588455); // Default coordinates
                  }
                },
                icon: Icon(Icons.map),
                label: Text('Open Google Maps'),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(Colors.green),
                  foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                  padding: MaterialStateProperty.all<EdgeInsetsGeometry>(EdgeInsets.all(15)),
                  textStyle: MaterialStateProperty.all<TextStyle>(TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _makePhoneCall('+918497920037');
                },
                child: Text('Make Phone Call'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _startCallTimer(); // Start call timer manually for testing
        },
        tooltip: 'Start Call Timer',
        child: Icon(Icons.timer),
      ),
    );
  }
}
*/
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_latestNotificationMessage != null &&
                  !_openedFromNotification)
                Card(
                  color: Colors.orange[50],
                  margin: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 15),
                  child: ListTile(
                    leading: Icon(
                        Icons.notification_important, color: Colors.red),
                    title: Text(
                      'Latest Notification:',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _latestNotificationMessage!,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  if (_latestNotificationMessage != null) {
                    try {
                      final urlPattern = RegExp(
                          r'Location: (https://www\.google\.com/maps/search/\?api=1&query=[^ ]+)');
                      final match = urlPattern.firstMatch(
                          _latestNotificationMessage!);
                      if (match != null) {
                        final Uri uri = Uri.parse(match.group(1)!);
                        final query = uri.queryParameters['query'];
                        if (query != null) {
                          final coords = query.split(',');
                          final double latitude = double.tryParse(coords[0]) ??
                              0;
                          final double longitude = double.tryParse(coords[1]) ??
                              0;
                          if (latitude != 0 && longitude != 0) {
                            _openGoogleMaps(latitude, longitude);
                          }
                        }
                      }
                    } catch (e) {
                      print('Error parsing coordinates: $e');
                      _openGoogleMaps(
                          44.427963, -110.588455); // Default coordinates
                    }
                  } else {
                    _openGoogleMaps(
                        44.427963, -110.588455); // Default coordinates
                  }
                },
                icon: Icon(Icons.map),
                label: Text('Open Google Maps'),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(
                      Colors.green),
                  foregroundColor: MaterialStateProperty.all<Color>(
                      Colors.white),
                  padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                      EdgeInsets.all(15)),
                  textStyle: MaterialStateProperty.all<TextStyle>(
                      TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _makePhoneCall('+919849455770');
                },
                child: Text('Make Phone Call'),
              ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            _openEmergencyContacts(context);
          },
          child: Text('Emergency Contacts'),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WildfireHandlingScreen(),
              ),
            );
          },
          icon: Icon(Icons.security),
          label: Text('Wildfire Handling Tips'),
          style: ButtonStyle(
            backgroundColor:
            MaterialStateProperty.all<Color>(Colors.red),
            foregroundColor:
            MaterialStateProperty.all<Color>(Colors.white),
            padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                EdgeInsets.all(15)),
            textStyle: MaterialStateProperty.all<TextStyle>(
                TextStyle(fontWeight: FontWeight.bold)),
                ),
             ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => EmergencyKitChecklist()),
            );
          },
          icon: Icon(Icons.checklist),
          label: Text('Emergency Kit Checklist'),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _startCallTimer(); // Start call timer manually for testing
        },
        tooltip: 'Start Call Timer',
        child: Icon(Icons.timer),
      ),
    );
  }
}
void _openEmergencyContacts(BuildContext context) async {
  const List<Map<String, String>> emergencyContacts = [
    {'Fire Department': 'tel:+911'},
    {'Police': 'tel:+100'},
    {'Ambulance': 'tel:+102'},
    {'Disaster Management': 'tel:+1070'}
    // Add more emergency contacts as per your region
  ];
  // Show a dialog with options to call emergency contacts
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Emergency Contacts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var contact in emergencyContacts)
              ListTile(
                title: Text(contact.keys.first),
                onTap: () {
                  _makePhoneCall(contact.values.first);
                  Navigator.pop(context); // Close dialog on selection
                },
              ),
          ],
        ),
      );
    },
  );
}
void _makePhoneCall(String phoneNumber) async {
  if (await canLaunch(phoneNumber)) {
    await launch(phoneNumber);
  } else {
    throw 'Could not launch $phoneNumber';
  }
}
