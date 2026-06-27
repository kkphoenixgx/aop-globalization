FROM dart:stable

WORKDIR /app

# Copy the SDK itself because it's a local path dependency
COPY sdk/dart /sdk/dart

# Copy the application source code
COPY test/realease/dart-panteao/ .

# Resolve dependencies
RUN dart pub get

# Command to run the application
CMD ["dart", "run", "main.dart"]
