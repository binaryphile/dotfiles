# URMA

Read `~/projects/urma/obsidian/URMA_PROJECT_UNDERSTANDING.md` before starting
work. It covers the architecture, API proxying, device communication, data
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

Key abstractions: **Rest** (HTTP singleton with multi-tenancy headers),
**SCI/RCI** (XML device communication), **useV1Api** (paginated SWR hook),
**useMongo** (MongoDB-backed preferences).

## Change impact checklist

- **API endpoint?** Check `api-constants.ts`, the `Rest` call site, the SWR
  hook, and whether the middleware needs special handling.
- **Form behavior?** Check Formik's `enableReinitialize`, SWR's
  `revalidateOnFocus`, and whether pending state persists across steps.
- **Feature flag?** Check MongoDB `features` collection, `useFeatures()` hook,
  and `FEATURE_FLAGS` env var. Some flags are per-account, some per-environment.
- **Authentication?** Check both OAuth and JSession paths. The feature flag
  selects which runs. Test both.
- **Device operation?** Check the SCI mixin (sci.js), the RCI wrapper (rci.ts),
  and the XML schema DRM expects. Cached vs. fresh matters.
- **New page?** Add under `(pages)/`, follow the route group pattern, check
  `next.config.js` redirects.
- **E2E test?** Check auth and db fixtures, use `test-` prefix for cleanup,
  follow Page Object Model in `urma-test/ui/pages/`.

## Key architectural facts

- URMA is a frontend proxy for DRM (Digi Remote Manager). All business data
  and device connectivity live in DRM's Java/Spring backend.
- Middleware at `src/middleware.ts` rewrites `/api/ws/*` requests to
  `DRM_ADDRESS` and injects auth tokens. The browser never talks to DRM.
- Multi-tenancy: `Account-Filter` header scopes reads, `Actor` header scopes
  writes. Getting these wrong exposes other accounts' data.
- SWR + Formik tension: SWR's `revalidateOnFocus` returns new object
  references that can reset Formik forms. Guard with refs or disable
  `enableReinitialize` selectively.
- MongoDB stores preferences and feature flags, not business data.
- Releases: `release/YY.MM.DD` branches, biweekly, GitLab CI → Docker →
  FluxCD → Kubernetes.
