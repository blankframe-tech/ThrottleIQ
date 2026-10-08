sed -i '' '/- name: Build Android Release/i\
      - name: Create mock key.properties\
        run: echo "storeFile=mock.jks\nstorePassword=mock\nkeyAlias=mock\nkeyPassword=mock" > android/key.properties\
' .github/workflows/ci.yml
