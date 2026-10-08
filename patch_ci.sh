sed -i '' '/- run: flutter test/a\
      - run: flutter test --coverage\
      - name: Build Android Release\
        run: flutter build apk --release' .github/workflows/ci.yml
