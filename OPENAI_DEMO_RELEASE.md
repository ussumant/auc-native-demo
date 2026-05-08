# AUC Native 0.1.1 OpenAI Demo

This candidate release is isolated from the already shared demo artifacts.

## Artifact

- Branch: `demo/openai-only-seeded-key`
- Tag: `v0.1.1-openai-demo`
- DMG: `dist/AUCNative-0.1.1-openai-demo.dmg`
- Checksum: `dist/AUCNative-0.1.1-openai-demo.dmg.sha256`

## Rollback

If this candidate does not work, use the previous demo DMG:

- `v0.1.0-demo`
- `v0.1.0-demo-slim-rc1`

Do not overwrite those release assets while testing this candidate.

## Build

Manual key build:

```bash
AUC_PACKAGE_PROFILE=openai-demo ./script/package_dmg.sh
```

Seeded throwaway key build:

```bash
AUC_PACKAGE_PROFILE=openai-demo \
AUC_DEMO_OPENAI_API_KEY="sk-..." \
./script/package_dmg.sh
```

The seeded key is packaged into the app bundle and is extractable. Use only a
throwaway low-budget key and revoke it after demo review.

## Notarization

This Mac must have a `Developer ID Application` signing identity before the DMG
can be notarized.

```bash
security find-identity -v -p codesigning
AUC_PACKAGE_PROFILE=openai-demo AUC_NOTARIZE=1 ./script/package_dmg.sh
```

The script uses `auc-notary` by default. Override with `AUC_NOTARY_PROFILE`.

## Demo Path

1. Install from DMG.
2. Complete onboarding.
3. Press `Option+B`.
4. Run `/new-task Say DMG OK and nothing else.`
5. Confirm output is exactly `DMG OK`.
