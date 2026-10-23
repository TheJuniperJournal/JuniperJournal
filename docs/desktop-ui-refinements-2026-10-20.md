# Desktop refinement implementation

The implementation extends the existing Manrope/Inter typography, green palette,
44px controls, 48px primary actions, and shared journal content-width rules.
Desktop panels use flexible widths with a readable maximum rather than stretching
individual mobile controls. Tables and matrices scroll horizontally inside their
own viewport. The established single page shell and full-window modal backdrop
remain in use.

## Shared components

- `filter_checkbox.dart`: one square checkbox appearance for filter sheets and
  inline project/community filters; selection callbacks retain their existing logic.
- `compact_list_item.dart`: consistent numbered/leading body and removal geometry,
  used for design objectives and material rows. Prose grows from a compact two-line
  objective field instead of a fixed oversized box.
- `evidence_cell_field.dart`: direct table/graph editing without nested borders.
- `evidence_description_field.dart`: five initial lines with unrestricted vertical
  growth for evidence descriptions and collection-level captions.
- `journal_publication.dart`: successful publication requests the existing Home,
  refreshes its feed, selects Home, and resets the feed scroll state. Draft and back
  actions do not invoke this event. Failed submissions retain draft status.

## Main feature files

- `project_development_flow.dart`: wider ideas, learning and decision-matrix content;
  minimum readable matrix columns with local overflow; compact objectives;
  responsive expanded root-cause cards; completion navigation.
- `project_dashboard.dart`, `project_impact_totals.dart`: consistent dashboard canvas,
  persisted project awards, zero empty totals, category totals and measurements
  grouped by unit. The unrelated placeholder 12.4-hour total is replaced by zero
  with “No time recorded”, since this app has no persisted time-tracking field.
  Uses existing backend awards; adds no invented scoring rules.
- Learning-module `table_block_editor.dart`: new 3×3 tables, text/numeric direct cell
  editing, existing add/remove/reorder actions and saved-data round trips.
- `graph_block_editor.dart`: wide live chart, data hover summary, responsive pie
  rendering and wrapping legends; existing chart types retained.
- `link_block_editor.dart`: full-width preview and expanding evidence description.
- Image, text, video and sketch editors: expanding descriptions; per-image captions
  explicitly labelled and associated with each image, separate from collection text.
- `home.dart`, `journal_entry_editor.dart`: publication refresh and navigation;
  newest activity ordering; submission confirmation; draft behavior preserved.
- `user_profile.dart`: live name/username search and a bounded lazy friends list;
  management/search controls sit outside the scrolling list.
- `project_filter_sheet.dart`, `project_collaboration_tab.dart`,
  `community_project_library.dart`, `app_theme.dart`: shared checkbox conventions.
- `tool/build_web.sh`: optional `JUNIPER_PREVIEW_CACHE_BUST=1` generates revision
  URLs to prevent obsolete local preview bundles; production/offline caching keeps
  Flutter defaults.

## Verification

96 targeted tests pass. The release web build succeeds. Static analysis of
`lib/` reports no errors (existing lint warnings and informational notices remain).

Widget coverage includes mobile (390px), tablet (768px), desktop (1440px) evidence
editing and every assessment type; table prose editing; live graph repainting;
filter toggling; saved table round trips; objective/matrix workflows; publication
callbacks after persistence; draft/material saving; category totals and unit
separation; identical dashboard header positions across tabs.

Chrome review verifies square checkmarks and independent multiselection in the
full-window filter popup, plus live friends search and its no-results state.
No live journal was published or deleted for verification. Publication persistence
and impact create/edit/delete aggregation are tested using repository fixtures.
Existing visibility queries and backend scoring/migrations are unchanged. No
schema changes or deployment are part of this update.

Graph hover currently provides the plotted data summary; it does not implement
chart zoom/pan or remote link metadata scraping. Link cards use supplied title,
URL and description with the existing metadata fallback.
