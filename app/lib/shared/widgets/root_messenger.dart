import 'package:flutter/material.dart';

/// The app-wide [ScaffoldMessenger], wired into `MaterialApp.router` in
/// app.dart. For feedback raised outside any screen's context — e.g. a follow
/// link opened from the system camera (follow_link_listener.dart).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
