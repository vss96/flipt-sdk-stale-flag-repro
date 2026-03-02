FROM eclipse-temurin:25-jdk-alpine AS build
WORKDIR /app
COPY . .
RUN ./gradlew :identity-server:bootJar --no-daemon

FROM eclipse-temurin:25-jre-alpine
WORKDIR /app
COPY --from=build /app/identity-server/build/libs/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
