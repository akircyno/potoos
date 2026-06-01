# LitratoLink PWA Beta Access

Use this after Sprint 1 proof works and before TestFlight.

## Goal

Deploy Flutter Web as a private beta link so trusted testers can use LitratoLink in a browser.

## Local Preview

From VS Code terminal:

```powershell
cd C:\dev\LitratoLink\app
flutter build web --release
py -m http.server 8091 --directory build\web
```

Open:

```text
http://localhost:8091
```

## Hosted Beta Checklist

Before sharing the hosted beta link:

- Build with `flutter build web --release`.
- Upload `app/build/web` to the hosting provider.
- Add the hosted URL to Supabase Auth redirect URLs.
- Add the hosted URL to Google OAuth authorized JavaScript origins.
- Add the Supabase callback URL to Google OAuth authorized redirect URIs.
- Test Google login on the hosted URL.
- Test upload, download, and Save All ZIP.
- Share only with trusted testers.

## GitHub Pages Beta Deploy

This repo includes `.github/workflows/pwa-beta.yml`.

To use it:

1. Push to `main`.
2. Open the GitHub repository.
3. Go to **Settings > Pages**.
4. Set **Build and deployment > Source** to **GitHub Actions**.
5. Open **Actions > PWA Beta Deploy**.
6. Run the workflow manually, or let it run after app changes.

Expected beta URL:

```text
https://akircyno.github.io/litratolink/
```

After the first successful deploy, add this URL to:

- Supabase Auth redirect URLs
- Google OAuth authorized JavaScript origins

## Notes

- PWA beta is not the public launch.
- Keep using the development/staging Supabase project for this phase.
- If the browser shows a blank screen after a new build, clear site data and unregister the old service worker.
