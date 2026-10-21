# bcv_calculadora



compilo con 

docker run --rm -v "$PWD":/work -w /work \                                 
  -v gradle-cache:/root/.gradle \
  -v pub-cache:/root/.pub-cache \
  -e GRADLE_OPTS="-Dorg.gradle.daemon=false" \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c "flutter pub get && flutter build apk --release"
