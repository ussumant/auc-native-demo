# AUC Design Token Mapping

Native AUC maps its Swift design system from the latest Electron AUC token sources:

- `/Users/sumant/dev/personalos/Coding/agent-computer/accomplish/apps/web/src/client/styles/globals.css`
- `/Users/sumant/dev/personalos/Coding/agent-computer/accomplish/apps/web/tailwind.config.ts`
- `/Users/sumant/dev/personalos/Coding/agent-computer/accomplish/apps/web/public/fonts`

## Swift Target

The native source of truth is `AUCDesign` in:

- `/Users/sumant/dev/personalos/Coding/auc-native/Sources/AUCNativeApp/Views/DesignTokens.swift`

## Token Families

| Electron token family | Native mapping |
| --- | --- |
| `--auc-primary`, `--auc-primary-dark`, `--auc-primary-light`, `--auc-primary-vlight` | `AUCDesign.ColorToken.primary`, `primaryDark`, `primaryLight`, `primaryVeryLight` |
| `--auc-void`, `--auc-surface`, `--auc-elevated` | `void`, `surface`, `elevated`, plus semantic `background`, `card`, `popover` |
| `--auc-n900` through `--auc-n100` | `n900` through `n100`, plus semantic foreground/muted/border/input aliases |
| `--auc-success`, `--auc-warning`, `--auc-error` | `success`, `warning`, `error`, plus `green`, `amber`, `red` aliases |
| Provider/todo tokens from Tailwind | `providerBackground*`, `providerAccent*`, `todoProgressPending`, `todoItem*` |
| Tailwind `boxShadow` values | `AUCDesign.Shadow.sm`, `default`, `md`, `lg`, `xl`, `xxl`, `card`, `cardHover`, `aucGlow` |
| CSS `--radius: 0.75rem` | `AUCDesign.Radius.base`, with component radii mapped to `12` |
| AUC font faces | `AUCDesign.FontToken.sans/display/mono`, with bundle registration at app launch |
| Main shell dimensions | `sidebarWidth`, `activePanelWidth`, `commandMaxWidth`, `runDetailMaxWidth`, launcher/settings sheet and pill widths |

## Runtime Font Packaging

`script/build_and_run.sh` copies Electron web fonts into:

`dist/AUCNative.app/Contents/Resources/fonts`

`AUCNativeApp` registers those fonts with CoreText on launch, so SwiftUI text can use Space Grotesk and Instrument Serif through `AUCDesign.FontToken`.
