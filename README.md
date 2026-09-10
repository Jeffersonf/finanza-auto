# Finanza Auto

Standalone web app and Flutter Android app for managing the costs, maintenance and mileage of a car. This repository is intentionally independent from the main Finanza project.

## Acesso rápido

- Website: https://jeffersonf.github.io/finanza-auto/
- APK: disponível como artefato no workflow **Build Android APK** do GitHub Actions

## Run locally

From this folder, run:

```bash
python -m http.server 4173
```

Then open `http://localhost:4173`.

## Included in this version

- Responsive dashboard in Portuguese-BR
- Vehicle selector with saved selection
- Expense and quick-entry flow with validation
- Recent activity persisted in `localStorage`
- Monthly expense chart with 6/12-month views
- Maintenance health, documents and mileage summary sections
- No build step, backend, API key or dependency on Finanza

## Flutter / Android

The Android app lives in `mobile/` and uses the same normalized backup as the web app. It includes:

- Dashboard, history, analytics and vehicle areas
- Real imported Drivvo records loaded on first launch
- Local persistence with `shared_preferences`
- Refuel and expense registration, editing and deletion
- JSON backup copy and restore from the clipboard
- Portuguese date and currency formatting

GitHub Actions builds the release APK automatically on every push to `main`.

The dashboard is populated with the real Drivvo export stored in `data/real-data.js`. A normalized backup is kept in `data/finanza-auto-backup.json`, and the original CSV is preserved at `data/source/20260422_164640_DRIVVO.csv`.

The repository is public to support GitHub Pages. The included backup contains personal vehicle and expense history; keep local copies private when sharing or forking the project. A backend can be added later without coupling this project back to Finanza.
