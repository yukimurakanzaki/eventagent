# Wargakas production documentation

Wargakas is a transparent shared cashbook for community events (Flutter app for Android, iOS and web, backed by Supabase).

| File | Audience | Purpose |
|---|---|---|
| [privacy-policy.md](privacy-policy.md) | Users, store reviewers, regulators | GDPR/CCPA/UU PDP-aware privacy policy with an Indonesian summary |
| [terms-of-service.md](terms-of-service.md) | Users | Terms of use: record-keeping tool, not a bank or payment service |
| [play-store-listing.md](play-store-listing.md) | Founder, store submissions | Descriptions (EN, ID and short ones in 5 more languages), Play Data safety answers, App Store privacy label, screenshot list, account-deletion URL requirement |
| [production-runbook.md](production-runbook.md) | Engineer/operator | Step-by-step go-live, release, monitoring, scaling, security, incident response, QA checklist |

## Before you publish anything

1. Read section 0 of the runbook: the public share link currently returns participant phone numbers, which contradicts the privacy policy. Fix and verify before launch.
2. Replace every `[placeholder]` in square brackets. Find them with:
   ```bash
   grep -rn "\[[A-Z][^]]*\]" docs/*.md
   ```
   Main ones: `[Operator name]`, `[Operator address]`, `[Support email]`, `[Supabase region]`, `[Effective date]`, `[Governing law]`, `[Jurisdiction/city]`, `[Account deletion web page URL]`, `[Privacy policy URL]`, `[Email provider]`, `[Reviewer email]`/`[Reviewer password]`, `[PROJECT_REF]`.
3. Host the privacy policy, terms and account-deletion page at public URLs (for example on the GitHub Pages site) and enter them in both stores.
4. Have a lawyer review the policy and terms for your operating jurisdiction before launch; these are practical drafts, not legal advice.
