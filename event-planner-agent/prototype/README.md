# WargaKas prototype

Open `index.html` directly, or serve this folder with any static web server:

```bash
python -m http.server 8765
```

Then open `http://127.0.0.1:8765/`.

The prototype has no build step and stores demo edits in browser `localStorage`. Use **Reset contoh data** in the event menu to restore the fixed Wisata Dieng scenario. The Ringkasan page now includes local reminders, an offline status indicator, and a visible queued-change model. This is a flow prototype: it does not yet schedule reliable operating-system notifications or sync to a hosted database. Those behaviors belong to the planned mobile app shell.

The Laporan page provides a named portfolio/e-transcript with participant names, a print-ready PDF handoff, and a low-privacy WhatsApp-ready summary. It intentionally excludes bank account numbers and login data from both handoffs.
