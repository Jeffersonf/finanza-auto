# Finanza Auto

Standalone web app for managing the costs, maintenance, documents and mileage of a car. This repository is intentionally independent from the main Finanza project and from the Android app.

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

The dashboard is populated with the real Drivvo export stored in `data/real-data.js`. A normalized backup is kept in `data/finanza-auto-backup.json`, and the original CSV is preserved at `data/source/20260422_164640_DRIVVO.csv`.

This repository is private because the backup contains personal vehicle and expense history. A backend and the Android app can be added later without coupling this project back to Finanza.
