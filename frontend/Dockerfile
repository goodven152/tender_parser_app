# build
FROM cirrusci/flutter:3.29.0 AS build
WORKDIR /app
COPY frontend/ .
RUN flutter pub get
RUN flutter build web --release

# serve
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80