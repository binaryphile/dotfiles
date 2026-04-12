# URMA

Read `~/projects/urma/obsidian/URMA_PROJECT_UNDERSTANDING.md` before starting
work. It covers the governing flows (page load and save), failure archetypes,
error model, and a verification-oriented change checklist.

## Where to look first

| Area | Path |
|---|---|
| API proxy and auth | `urma-next/src/middleware.ts` |
| Authentication flow | `urma-next/src/lib/authenticate.ts` |
| HTTP client | `urma-next/src/lib/use-rest.tsx` |
| Data fetching hooks | `urma-next/src/lib/use-*.tsx` |
| Device communication | `urma-next/src/lib/sci/` |
| Feature flags | `urma-next/src/lib/use-features.ts` |
| Feature pages | `urma-next/src/app/(authenticated)/(pages)/` |
| Provider hierarchy | `urma-next/src/app/(authenticated)/providers.tsx` |
| CI pipeline | `.gitlab-ci.yml` |
| E2E tests | `urma-test/tests/` |

Key abstractions: **Rest** (HTTP singleton with tenant headers), **SCI/RCI**
(XML device communication), **useV1Api** (paginated SWR hook), **useMongo**
(MongoDB preferences).

## Change impact checklist

- **API contract?** Check endpoint, hook, types, pagination, cache key,
  mutation invalidation. Verify loading/empty/error states. Verify account
  switching isolates results.
- **Multi-step form?** Check initialization, edit-mode rehydration,
  `revalidateOnFocus` + `enableReinitialize`. Verify unsaved edits survive
  revalidation. Verify create/edit preserve step state.
- **Tenant scope?** Check Actor/Account-Filter injection, MongoDB filters.
  Verify account switch doesn't leak stale rows. Verify writes hit the
  selected account.
- **Account switch?** Verify cache invalidation covers all account-scoped
  hooks. Verify no component retains stale context from prior account.
- **Authentication?** Check both OAuth/JSession paths, middleware extraction,
  cookies to DRM. Verify page load, navigation, and API requests all fail
  and recover on session expiration.
- **New page?** Three-layer pattern (page.tsx → client-wrapper → actual,
  ssr:false). Identify failure archetype. Check redirects. Add E2E with POM.

## Key architectural facts

- URMA is a frontend proxy for DRM. Every browser-to-DRM request passes
  through middleware. Business data and device connectivity live in DRM.
- Two governing flows:
  - **Load:** route → providers (Auth, Cache) → account-scoped SWR fetch
  - **Save:** Formik → Rest (tenant headers) → middleware (auth) → DRM →
    SWR mutate → re-render → Formik reinitialize risk
- Pages: server page.tsx → client-wrapper (ssr:false) → actual page with SWR.
  Page-rendering server components do not fetch from DRM.
- SWR + Formik tension: revalidateOnFocus returns new refs that reset forms.
- Errors: no global interceptor. Save failures → visible FlashMessage.
  Background revalidation failures → silent stale data.
- Tenant headers: Account-Filter scopes reads, Actor scopes writes. Wrong
  headers = silent cross-tenant data. Account switch invalidates cache.
- Authorization: four layers — middleware, DRM, provider role gating, flags.
- Releases: release/YY.MM.DD, GitLab CI → Docker → FluxCD → K8s.
