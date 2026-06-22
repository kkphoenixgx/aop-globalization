FROM public.ecr.aws/docker/library/dart:stable
WORKDIR /app
COPY sdk sdk
COPY client.dart .
RUN echo 'name: test_client\nenvironment:\n  sdk: ">=3.0.0 <4.0.0"\ndependencies:\n  panteao_client:\n    path: ./sdk' > pubspec.yaml
RUN dart pub get
CMD ["dart", "run", "client.dart"]
