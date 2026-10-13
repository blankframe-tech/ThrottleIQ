sed -i '' '/if (keystorePropertiesFile.exists()) {/i\
            if (!keystorePropertiesFile.exists()) throw GradleException("key.properties not found")\
' app/android/app/build.gradle.kts
