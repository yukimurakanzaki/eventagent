# Wargakas production documentation

Wargakas is a transparent shared cashbook for community events (Flutter app for Android, iOS and web, backed by Supabase).

| File | Audience | Purpose |
|---|---|---|
| [privacy-policy.md](privacy-policy.md) | Users, store reviewers, regulators | GDPR/CCPA/UU PDP-aware privacy policy with an Indonesian summary |
| [terms-of-service.md](terms-of-service.md) | Users | Terms of use: record-keeping tool, not a bank or payment service |
| [play-store-listing.md](play-store-listing.md) | Founder, store submissions | Descriptions (EN, ID and short ones in 5 more languages), Play Data safety answers, App Store privacy label, screenshot list, account-deletion URL requirement |
| [account-deletion.md](account-deletion.md) | Users, Google Play | Public page explaining how to delete an account in or outside the app |
| [production-runbook.md](production-runbook.md) | Engineer/operator | Step-by-step go-live, release, monitoring, scaling, security, incident response, QA checklist |

## Before you publish anything

1. Operator details use defaults: "the Wargakas project team", Indonesia, Indonesian law (Jakarta), support through https://github.com/yukimurakanzaki/eventagent/issues, data region Singapore. Change them in `privacy-policy.md` and `terms-of-service.md` if you register a company, add a support email, or pick another Supabase region.
2. The only details left to supply at store submission are a review account (create one in Supabase and enter it in the Play Console / App Store Connect, never in this repo) and the publishable key (GitHub secret).
3. Public URLs for the stores: privacy policy, terms and `account-deletion.md` are linked from GitHub (see `play-store-listing.md`). The in-app Settings → About links point to the same pages.
4. Have a lawyer review the policy and terms before a large launch; these are practical drafts, not legal advice.
