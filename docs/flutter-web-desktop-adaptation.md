# Flutter Web and desktop adaptation

## Initial assessment

Web was already enabled (`web/index.html`, manifest and web build support), and
Flutter detects Chrome as a target. No platform regeneration was needed. The
existing release preview was mobile-shaped, not a separate web application.

| Area | Findings and first-pass changes |
| --- | --- |
| Backend | Existing Supabase project, tables, RLS, storage and models are shared. No backend migration or auth-setting changes were made. |
| Plugins | Registered web implementations exist for app_links, file_selector, image_picker, shared_preferences, url_launcher and video_player. Other UI packages (SVG, calendar, math, editor, Bloc) compile into the web target. This is compile compatibility, not exhaustive feature certification. |
| Images/uploads | Storage already uses XFile.readAsBytes and uploadBinary. Three community forms used dart:io/FileImage/Image.file for local previews. Replaced with one byte-based preview widget shared across platforms. |
| Browser media limits | Native camera availability, browser permission prompts, video codecs/autoplay, third-party image CORS and downloads still need device/browser acceptance testing. Camera-roll and video behavior cannot be assumed identical to iOS. |
| Authentication | Supabase initialization restores the existing session. Added a session-aware startup gate. Google OAuth and signup confirmation use the current web origin; the native callback is unchanged. Server allowlists were not edited. |
| Local startup | Debug mode no longer automatically bypasses authentication. The old restoration preview remains explicitly opt-in via LOCAL_PREVIEW=true. |
| Navigation | Most screens use Navigator.push(MaterialPageRoute); login/signup use named routes. Flutter currently uses hash URLs. Direct project, community and journal URLs are not implemented. Hosting fallback alone will not provide those routes. |
| Shared widgets | Existing home, explore, library and profile screens are reused by the adaptive shell. Services and business logic are unchanged. |
| Desktop shell | At >=1000 logical pixels, use a 224px side rail with Home, Explore, Journal Library, Profile and Create. Below that width, retain the existing mobile bottom bar. Content is capped at 1440px. Resizing preserves the body subtree and its state. Alt+1..4 switches sections. |
| Existing screens | Many journal forms intentionally remain narrow; project dashboards, nested navigation, community management, data tables and editor toolbars need follow-up desktop layouts. |

## Local Chrome preview

From this checkout's root, with Flutter on PATH:

```sh
./tool/run_web.sh
```

This runs `flutter run -d chrome` on **http://127.0.0.1:5174/**, separate from the
existing preview on port 5173. Sign in with an existing Juniper account.
If Flutter is not on PATH, set FLUTTER_BIN to its executable before the command.
The server is local-only and must keep running for the preview to remain available.

The helper reads the existing .env without modifying it and generates a temporary,
allowlisted JSON configuration containing only SUPABASE_URL and SUPABASE_KEY.
Secret keys and service-role JWTs are rejected. Temporary config files are removed
when the development process exits. Production artifacts must never contain
service-role keys, private tokens or a preview authentication bypass.

## Validation and limits

- `flutter devices` detects Chrome and macOS.
- `flutter run -d chrome` starts successfully and initializes Supabase.
- Chrome landing -> login navigation was inspected live; screenshot:
  `/tmp/juniper-chrome-login.png`.
- Adaptive-shell tests cover desktop/mobile navigation, Create, and body state
  preservation across a window resize. Native-style tab state and project browse
  regression tests also pass.
- Browser/native callback unit tests verify exact URL formatting.
- Three configuration tests verify allowlisting and privileged-key rejection.
- Release web build verified separately through tool/build_web.sh.
- No iOS device build or device-specific camera test was performed in this session.
- Live login/upload/edit using a real account still needs user sign-in in Chrome;
  no credentials were obtained or user content created for that check.
- Same backend means the same stored data; not every screen subscribes to realtime
  updates. Existing refresh/reload behavior still applies outside subscribed views.

## Prioritized roadmap

1. **Browser authentication and routes (before a public pilot).** Review exact local
   and production redirect allowlists with the owner. Test Google login, signup,
   confirmation, resend and session refresh. Add a dedicated password-recovery
   route: the existing change-password screen requires the current password and
   is not a complete recovery flow. Introduce canonical, permission-checked
   project/community/journal URLs and route restoration across login. Test browser
   back/forward and reload from each URL; keep hash URLs until that work is ready.
2. **Project dashboard and navigation.** Keep a consistent desktop shell through
   nested project/community pages. Use a two-column project overview, readable
   development cards and a desktop details panel while retaining mobile layouts.
3. **Journal editing.** Widen editor canvases and evidence previews on desktop;
   keep prose readable. Adapt staged forms, tables, toolbar overflow and keyboard
   traversal. Preserve autosave and one-time completion rewards.
4. **Communities and collaboration.** Split list/detail views on wide windows;
   adapt member/admin dialogs and notification panels; confirm selected rows and
   controls remain accessible at increased text scale.
5. **Media, accessibility and polish.** Test photo/file/video workflows in Chrome,
   Safari and Firefox; keyboard-only use, focus indicators, narrow browser windows,
   screen-reader labels, zoom, touch and slow/offline saves. Widen auth forms with
   a sensible content cap and explicit accessible field labels.
6. **Release acceptance.** Real-account cross-device project/journal editing and
   storage round trip, cold start and sign-out, mobile device smoke tests, asset
   caching, runtime error review and production build size/startup profiling.

## Future hosting and Wix integration — preparation only

Intended addresses:

- https://www.junejournal.org/ remains the Wix public website.
- https://app.junejournal.org/ would serve the Flutter application.
- Both installed and browser apps continue using the same Supabase backend.

Prepare a release bundle locally:

```sh
./tool/build_web.sh
```

Output is `build/web`. This command does not publish anything. Do not supply
LOCAL_PREVIEW=true to a production build. Current Firebase configuration serves
that directory, excludes source maps and dotfiles, provides an index fallback,
and avoids caching the main entry files. No Firebase project was created or bound.
Cloudflare Pages can alternatively serve the same directory; select the hosting
provider and review its SPA fallback and caching configuration before deployment.

After approval, the remaining launch work is to select/create a hosting project,
configure its HTTPS custom-domain connection, review Supabase Site URL/allowed
redirects and email templates without breaking the mobile callback, then add only
the app-subdomain DNS record at the authoritative DNS provider. Leave Wix's main
website and email records intact. Add Open App / Sign In links on Wix to the app.
Test the deployed URL before promoting it. No DNS, auth settings, RLS, schema,
production environment values, or public deployment changed in this session.

Official references:
- Flutter web build/release: https://docs.flutter.dev/deployment/web
- Supabase redirect configuration: https://supabase.com/docs/guides/auth/redirect-urls
- Firebase static hosting configuration: https://firebase.google.com/docs/hosting/full-config
