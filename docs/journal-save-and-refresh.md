# Journal saving and browser refresh

Journal snapshots now use IndexedDB on the web, with existing preference snapshots read as a migration fallback. Preferences remain a fallback if IndexedDB is unavailable. Large evidence/image drafts are no longer constrained by localStorage's small quota. Writes wait for transaction completion before reporting success.

For kept drafts, local protection happens before the database update. If database synchronization fails, the latest snapshot remains available after refresh and the UI distinguishes local protection from a confirmed server save. Unexpected write exceptions release the autosave lock, allowing a later retry. A successful database insert is never reported as failed merely because local snapshot cleanup failed afterward.

Page restoration is account-scoped and works outside local-preview mode. It restores Home/Explore/Library/Profile, project tabs, phase dashboards, journal editors/previews, project settings, materials/impact/activity pages, communities, chats and public profiles. Popup routes do not replace the remembered page. Project access is fetched again on refresh; remembered navigation does not grant access. Journal navigation metadata preserves the last autosaved stage. Browsing an empty editor still does not create a project entry.

Chrome storage test writes and reads a 6 MB snapshot. Dart tests cover failed writes recovering, local protection during cloud failures, no duplicate draft insertion, save/discard exits, stage restoration and remembered pages. The connected preview was navigated to Explore, refreshed, and visibly remained on Explore.
