# Lokale Entwicklung mit Docker Compose

Startet Frontend, Backend und MariaDB auf dem eigenen Rechner. Es wird **kein AWS-Zugang** gebraucht:
die Datenbank läuft als Container, Fotos landen in einem lokalen Docker-Volume statt in S3.

## Voraussetzungen
- Docker mit Compose v2 (`docker compose version`)
- Internetzugang beim ersten Start (Images und Frontend-Quellcode werden geladen)

## Start in drei Schritten
```bash
cd docker-compose-local
cp .env.example .env          # lokale Werte; bei Bedarf Ports anpassen
docker compose up --build     # baut das Backend, holt das Frontend aus GitHub
```
Danach:

| Was | URL |
|---|---|
| Frontend | http://localhost:8081 |
| Backend-Health | http://localhost:8080/actuator/health |
| Backend-API | http://localhost:8080/v1/employees |

Stoppen: `Ctrl+C`, danach `docker compose down`. Mit `docker compose down -v` werden zusätzlich Datenbank und
Fotos gelöscht (frischer Start).

## Startreihenfolge
`mariadb` (Healthcheck) → `backend` (wartet auf gesunde DB, eigener Healthcheck) → `frontend` (wartet auf gesundes
Backend). Beim ersten Start legt das Backend das Schema an und füllt Demo-Daten ein.

## Umgebungsvariablen (`.env`)
| Variable | Bedeutung | Standard |
|---|---|---|
| `DB_NAME` | Name der Datenbank | `db_biztrips` |
| `DB_USER` / `DB_PASSWORD` | Zugang des Backends (Pflicht) | siehe `.env.example` |
| `DB_ROOT_PASSWORD` | Root-Passwort der DB (Pflicht) | siehe `.env.example` |
| `FRONTEND_PORT` / `BACKEND_PORT` | Ports auf dem Rechner | `8081` / `8080` |
| `FRONTEND_CONTEXT` | Quelle des Frontends | GitHub `main`, alternativ `../../refcard05-fe` |

Fehlt eine Pflichtvariable, bricht Compose mit einer klaren Meldung ab. Das Backend nutzt dieselben
Variablennamen wie in AWS (`DB_URL`, `DB_USER`, `DB_PASSWORD`, `APP_STORAGE_*`): nur die Werte unterscheiden sich.

## Eigene Frontend-Änderungen testen
Beide Repos nebeneinander klonen und in `.env` setzen: `FRONTEND_CONTEXT=../../refcard05-fe`, dann
`docker compose up --build`.

## Foto-Upload ausprobieren
```bash
curl -F "file=@foto.png;type=image/png" http://localhost:8080/v1/employees/1/photo
curl -o zurueck.png http://localhost:8080/v1/employees/1/photo
```
