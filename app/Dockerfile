FROM eclipse-temurin:25-jdk AS build
WORKDIR /app
COPY . .
RUN ./gradlew :app:bootJar --no-daemon

FROM eclipse-temurin:25-jre
WORKDIR /app
COPY --from=build /app/app/build/libs/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
