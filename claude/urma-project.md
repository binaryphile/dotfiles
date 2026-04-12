# URMA

Read `~/projects/urma/obsidian/URMA_PROJECT_UNDERSTANDING.md` before starting
work. It covers the governing change flow, server/client boundaries, error
model, page archetypes, and a verification-oriented change checklist.

## Where to look first

| Area | Path |
|---|---|
| API proxy and auth | `urma-next/src/middleware.ts` |
| Authentication flow | `urma-next/src/lib/authenticate.ts` |
| HTTP client | `urma-next/src/lib/use-rest.tsx` |
| Data fetching hooks | `urma-next/src/lib/use-*.tsx` |
| Device communication | `urma-next/src/lib/sci/` |
| API endpoints | `urma-next/src/lib/api-constants.ts` |
| Feature flags | `urma-next/src/lib/use-features.ts` |
| Shared components | `urma-next/src/app/(authenticated)/_common/` |
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
- **Authentication?** Check both OAuth/JSession paths, middleware extraction,
  cookies to DRM. Verify page load, navigation, and API requests all fail
  and recover on session expiration.
- **Device operation?** Check SCI mixin, RCI wrapper, XML schema. Verify
  cached and fresh paths match expectations.
- **Provider/context?** Check nesting order, cache invalidation on reorder,
  client-only boundary leaks.
- **New page?** Three-layer pattern (page.tsx → client-wrapper → actual,
  ssr:false). Identify archetype. Check redirects. Add E2E with POM.

## Key architectural facts

- URMA is a frontend proxy for DRM. Business data and device connectivity
  live in DRM's Java/Spring backend. Browser never contacts DRM directly.
- Governing flow: Formik → Rest (tenant headers) → middleware (auth, URL
  rewrite) → DRM → response → SWR mutate → re-render → Formik reinitialize
  risk.
- All pages: server page.tsx → client-wrapper (dynamic, ssr:false) → actual
  page with SWR. No server-side data fetching.
- SWR + Formik tension: revalidateOnFocus returns new refs that reset forms.
  Guard with refs or disable enableReinitialize selectively.
- Errors: no global interceptor. Save failures → FlashMessage (visible).
  Background revalidation failures → silent stale data.
- Multi-tenancy: Account-Filter scopes reads, Actor scopes writes. Account
  switch invalidates cache. Wrong headers = silent cross-tenant data leak.
- Authorization: four layers — middleware session, DRM backend, provider role
  gating, feature flag visibility.
- Releases: release/YY.MM.DD branches, GitLab CI → Docker → FluxCD → K8s.
