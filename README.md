# RefCard 05 – Backend (Spring Boot) auf AWS

> **Abgabe RefCard05:** Dokumentation mit Screenshots in [`docs/RefCard05-Ergebnis.md`](docs/RefCard05-Ergebnis.md) ·
> lokale Entwicklung mit Docker Compose in [`docker-compose-local/`](docker-compose-local/README.md) ·
> Frontend-Repo: [rtinase/refcard05-fe](https://github.com/rtinase/refcard05-fe)

Das Backend läuft als ECS-Service (Fargate) hinter einem ALB, nutzt eine MariaDB auf Amazon RDS und speichert
Mitarbeiterfotos in Amazon S3. Die Pipeline (`.github/workflows/ci-cd.yml`) baut, testet und deployt automatisch.

---

# Ausgangsprojekt: Spring Boot Backend + MariaDB

REST-API-Backend für die BusinessTrips-Applikation (Mitarbeitende, Business
Trips, Flüge, Meetings). Teil der CI/CD-Übungssequenz **RefCard 02–05**
(siehe [`docs/future/RefCard-03-RefCard-05-own-repos.md`](docs/future/RefCard-03-RefCard-05-own-repos.md))
— dieses Repository ist **RefCard 03**: Spring Boot Backend mit MariaDB.

## Tech-Stack

- Java 21, Spring Boot 4.1 (Web, Data JPA)
- MariaDB (lokal via Docker Compose) / H2 (Default, für Tests und schnellen lokalen Start)
- Maven (Maven Wrapper, kein lokales Maven nötig)

## Schnellstart

### Ohne Datenbank-Setup (H2, Default)

```bash
./mvnw spring-boot:run
```

Startet auf Port 8080 mit einer flüchtigen In-Memory-H2-Datenbank (Daten sind nach jedem Neustart weg, werden aber automatisch neu geseedet).

### Mit MariaDB und Frontend (persistent, wie in Produktion)

Das komplette System (Frontend, Backend, MariaDB) startet mit Docker Compose, ganz ohne AWS:

```bash
cd docker-compose-local
cp .env.example .env
docker compose up --build
```

Details, Ports und Umgebungsvariablen: [`docker-compose-local/README.md`](docker-compose-local/README.md).

Das Backend allein gegen eine eigene MariaDB starten (Zugangsdaten über Umgebungsvariablen, nichts davon steht im Code):

```bash
DB_URL=jdbc:mariadb://localhost:3306/db_biztrips DB_USER=... DB_PASSWORD=... \
  ./mvnw spring-boot:run -Dspring-boot.run.profiles=mariadb
```

- Die Demo-Daten werden nur beim allerersten Start eingefügt, ein Neustart der Applikation dupliziert sie nicht
- Profil `aws` = `mariadb` + Fotos in S3 (zusätzlich `APP_STORAGE_S3_BUCKET`)

### Tests ausführen

```bash
./mvnw test
```

## API

Basis-Pfad: `/v1`

| Endpoint | Beschreibung |
| --- | --- |
| `GET /v1/trips`, `POST /v1/trips`, `GET /v1/trips/{id}`, `DELETE /v1/trips/{id}` | Business Trips |
| `GET /v1/employees`, `POST /v1/employees`, `GET /v1/employees/{id}`, `PUT /v1/employees/{id}`, `DELETE /v1/employees/{id}`, `DELETE /v1/employees` | Mitarbeitende |
| `GET /v1/flights`, `POST /v1/flights`, `GET /v1/flights/{id}`, `PUT /v1/flights/{id}`, `DELETE /v1/flights/{id}`, `DELETE /v1/flights` | Flüge |
| `GET /v1/meetings`, `POST /v1/meetings`, `GET /v1/meetings/{id}`, `PUT /v1/meetings/{id}`, `DELETE /v1/meetings/{id}`, `DELETE /v1/meetings` | Meetings |
| `POST /v1/employees/{id}/photo`, `GET /v1/employees/{id}/photo` | Foto-Upload/-Download (lokal oder S3) |
| `POST /v1/signIn` | Login (Demo-User: `joe` / `1234`) |
| `GET /actuator/health` | Health-Check (Spring Boot Actuator) — prüft u. a. die Datenbankverbindung |

## Projektstruktur

```
src/main/java/ch/bbw/trips/   Applikationscode (Controller, Entities, Repositories, DTOs)
docker-compose-local/         Frontend + Backend + MariaDB lokal (Docker Compose)
infra/                        AWS-Skripte: Infrastruktur, ECS-Services, GitHub-Variablen/-Secrets
task-definition.json          ECS-Task-Definition (Vorlage, Werte aus GitHub-Variablen)
docs/exercises/               CI/CD-Übungen (EX-01 EC2, EX-02 Docker Hub, EX-03 ECS/RDS)
docs/reviews/                 Code-Reviews
docs/future/                  Planungsentscheidungen für RefCard 03–05
```

## Für Studierende

Der Tag [`v1-start`](../../releases/tag/v1-start) markiert den Ausgangspunkt für die Übungen in `docs/exercises/` — bewusst **ohne** `Dockerfile`, `.dockerignore`, `.github/workflows/deploy.yml` und `task-definition.json`, da ihr genau diese Dateien in EX-01/EX-02/EX-03 selbst erstellt.
