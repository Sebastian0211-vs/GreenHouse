# GreenHouse

GreenHouse is a Flutter (Web/Desktop/Mobile) application built as a school project to manage greenhouse operations: beds/parcels, plantings/crops, tasks, inventory, and basic analytics—backed by a PostgreSQL database.

> Status: actively developed (school project).  

---

## Features (high level)

- **Authentication / session** (simple project-oriented auth layer)
- **Beds / Parcelles management**: visualize beds and their plantings
- **Tasks**: view upcoming tasks, assign/unassign, track status and due dates
- **Inventory**: basic stock view and updates
- **Analytics**: simple dashboards and overview metrics

---

## Tech stack

- **Frontend:** Flutter (Material 3)
- **Database:** PostgreSQL
- **Target platforms:** Web + Desktop + Mobile (Flutter project structure)

---

## Repository structure

At the root you have a standard Flutter project layout (`lib/`, `web/`, `android/`, `ios/`, etc.) plus database assets.

Typical folders:

- `lib/` — Flutter source code (pages, services, widgets, SQL helpers)
- `DB/` — database scripts / notes / assets (schema, seed, queries)
- `web/`, `android/`, `ios/`, `windows/`, `linux/`, `macos/` — platform targets
- `CropHouse.png`

---

## Getting started

### Prerequisites

- Flutter SDK installed and configured (`flutter doctor` clean)
- A reachable PostgreSQL instance (local or hosted)
- (Recommended) VS Code or Android Studio with Flutter/Dart plugins

### 1) Clone

```bash
git clone https://github.com/Sebastian0211-vs/GreenHouse.git
cd GreenHouse
````

### 2) Install dependencies

```bash
flutter pub get
```
