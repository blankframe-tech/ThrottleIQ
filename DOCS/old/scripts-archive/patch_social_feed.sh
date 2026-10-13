#!/bin/bash
sed -i '' 's/      child: Container(/        child: Container(/g' app/lib/features/social/presentation/screens/social_feed_tab.dart
sed -i '' 's/    );/      ),\n    );/g' app/lib/features/social/presentation/screens/social_feed_tab.dart
