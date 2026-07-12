#!/bin/bash

# Find only root apps (skipping nested packages without a lib folder)
find /Users/blackbird/Everything/dev/repos/ThrottleIQ/old_versions -name pubspec.yaml -type f | while read -r pubspec_path; do
  dir=$(dirname "$pubspec_path")
  
  # Optimization: Ensure it's a buildable app, not an isolated package module
  if [ ! -d "$dir/lib" ]; then continue; fi

  echo "========================================================"
  echo "Building in $dir"
  echo "========================================================"
  cd "$dir" || continue
  
  # Measure time for just this specific repository block
  time {
    echo "Running flutter pub get..."
    flutter pub get
    
    echo "Building APK..."
    flutter build apk
    
    echo "Building iOS (no codesign)..."
    flutter build ios --no-codesign
  }
done

echo "All builds completed."
