sed -i '' '/<key>NSPhotoLibraryUsageDescription<\/key>/{
N
a\
	<key>NSPhotoLibraryAddUsageDescription</key>\
	<string>This app requires access to save photos to your photo library.</string>
}' app/ios/Runner/Info.plist
