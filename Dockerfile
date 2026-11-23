# --- Stage 1: Build ---
# Maven ist im Image enthalten: kein Download der Maven-Distribution pro Build
# (der Maven Wrapper lief auf GitHub-Runnern zeitweise in HTTP 429 von Maven Central).
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

# Dependencies zuerst: dieser Layer bleibt gecacht, solange sich pom.xml nicht ändert.
COPY pom.xml ./
RUN mvn -B dependency:go-offline

COPY src ./src
RUN mvn -B -q clean package -DskipTests

# --- Stage 2: Runtime ---
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

RUN addgroup -S app && adduser -S app -G app \
 && mkdir /app/uploads && chown app:app /app/uploads
COPY --from=build /app/target/*.jar app.jar
USER app

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-jar", "app.jar"]
