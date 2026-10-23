# Typography and color standard

Use `AppTypography` roles and `buildAppTheme()` on every screen. Avoid new literal font sizes or custom neutral text colors.

| Role | Size | Color |
| --- | --- | --- |
| Page/dialog title | 20 | Primary text |
| Section heading | 18 | Primary text |
| Evidence heading | 20 | Brand green |
| Field label | 14 | Primary text |
| Input/body text | 14 | Primary text |
| Helper/description text | 12 | Secondary gray |
| Validation requirement | 12 | Error red |
| Button text | 14 | Green for text/outline actions, white on filled green actions |
| Compact metadata/counters | 10 | Secondary gray |

Headings and labels use the weight defined by their role. Preserve status, score, chart-series and destructive-action colors when they convey meaning. Numeric dashboard displays and branded hero text use the display/hero roles rather than section headings. Respect system text scaling.

`JournalSectionHeader` provides the standard journal heading layout and applies the Evidence exception automatically. App bars and evidence editor headers share the page-title role. Text fields and Material buttons inherit their roles from the application theme; custom controls must explicitly use the same roles.

## Repeated controls and density

Use `AppMetrics` for control heights, default icon size, corner radius, and spacing. Shared widgets such as `SubmitButton`, `ItemActionMenu`, `EvidenceBlockHeader`, and `ProgressTracker` carry the corresponding structure. Compact metadata and dense cards may use caption/helper roles and smaller gaps, but should not introduce one-off font sizes or alternate neutral colors.

Use `ProgressTracker` for both project-development progress and journal stages. Omit `onSelected` for informational trackers; provide it only for navigable stages. Do not wrap informational tracker steps in click handlers. Preserve the same circles, connecting line, labels, and active marker.

## Font families

Use bundled Manrope at weight 600 for page titles, section headings, and evidence headings. Use bundled Inter for body text, inputs, tabs, and buttons: regular 400 for reading, medium 500 for labels/actions. Font files and their OFL licenses live in assets/fonts. Existing size roles and semantic colors remain in effect.

Title and name inputs have a minimum input height of 64 logical pixels. Keep single-line text vertically centered and preserve separate space for counters or validation.

Never display character counters on text inputs. Retain existing length validation where needed, but hide both native and custom counters.

## Spacing roles

Use 8px between a label and supporting helper text; 16px before its input; 24px between related fields/actions; 32px between sections; 40px for long-form journal sections. Compact card/table interiors may use smaller gaps. Fixed dashboard coordinates are separate from flow-layout spacing. Field labels and actions use Inter 14/500; descriptions use Inter 12/400; entered text uses Inter 14/400; page/section headings use Manrope 600.

## Journal completion

Journal tracker circles use completedJournalStageIndices from current required content, never navigation history. The current-stage underline is gray until that stage is complete. Development Progress remains an informational entry-count tracker. Drafts can be saved at any time, but final Submit checks every stage and lists missing stages. Completed status requires both valid stages and a successful submission; completed entries open read-only full previews and the owner's existing Edit action reopens the form.
