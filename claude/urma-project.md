# URMA

Read `~/projects/urma/obsidian/URMA_PROJECT_UNDERSTANDING.md` before starting
work. It covers the architecture, change flow, device communication, data
fetching patterns, testing, CI/CD, and a change impact checklist.

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
| Design documents | `obsidian/` |

Key abstractions: **Rest** (HTTP singleton with tenant headers), **SCI/RCI**
(XML device communication), **useV1Api** (paginated SWR hook), **useMongo**
(MongoDB-backed preferences).

## Change impact checklist

- **API contract change?** Check endpoint constant, hook wrapper, response
  types, pagination logic, cache key, mutation invalidation via `mutate()`,
  error normalization in `Rest`, tenant header injection, E2E data fixtures.
- **Multi-step form change?** Check fetched-to-local initialization,
  edit-mode rehydration, SWR `revalidateOnFocus` + Formik
  `enableReinitialize` interaction, step persistence, unsaved-change guard,
  save sequencing, post-save cache refresh.
- **Tenant-scoped change?** Check active account source, `Actor` vs
  `Account-Filter` headers in `Rest`, SWR cache scoping on account switch,
  server route handlers with user-scoped MongoDB filters.
- **Authentication change?** Check both OAuth and JSession paths (feature flag
  selects), middleware session extraction, page load vs API request behavior,
  session refresh/expiration, protected route redirects.
- **Device operation?** Check SCI mixin (sci.js), RCI wrapper (rci.ts), XML
  schema DRM expects, cached vs fresh response semantics.
- **Provider or context?** Check nesting order, account-scoped memoization,
  cache invalidation on reorder, client-only vs server boundary.
- **New page?** Identify archetype (inventory, detail, wizard, live,
  reporting), add under `(pages)/`, check `next.config.js` redirects, add
  E2E with Page Object Model.

## Key architectural facts

- URMA is a frontend proxy for DRM (Digi Remote Manager). Business data and
  device connectivity live in DRM's Java/Spring backend.
- The governing flow: user interaction → Formik state → Rest with tenant
  headers → middleware proxy with auth → DRM → response → SWR mutate →
  React re-render → Formik reinitialize risk.
- Multi-tenancy: `Account-Filter` scopes reads, `Actor` scopes writes.
  Switching accounts invalidates the SWR cache.
- SWR + Formik tension: SWR's `revalidateOnFocus` returns new object
  references that can reset Formik forms. Guard with refs or disable
  `enableReinitialize` selectively.
- Authorization is layered: middleware session, DRM backend, provider-level
  role gating, feature flag visibility.
- Per-account feature flags in MongoDB; server-side flags via FEATURE_FLAGS
  env var.
- Releases: `release/YY.MM.DD` branches, GitLab CI → Docker → FluxCD → K8s.
