# URMA

Read `~/projects/urma/obsidian/URMA_PROJECT_UNDERSTANDING.md` before starting
work. It covers the governing flows (page load and save), account-switch
mechanism, first-fetch race, error model, failure archetypes, and a
verification-oriented change checklist.

Also see `~/projects/urma/obsidian/URMA_SWOT.md` for strategic analysis.

## Where to look first

| Area | Path |
|---|---|
| API proxy and auth | `urma-next/src/middleware.ts` |
| Authentication flow | `urma-next/src/lib/authenticate.ts` |
| HTTP client and tenant headers | `urma-next/src/lib/use-rest.tsx` |
| Account switch mechanism | `urma-next/src/lib/use-account.ts`, `src/lib/disk-cache.ts` |
| Data fetching hooks | `urma-next/src/lib/use-*.tsx` |
| Device communication | `urma-next/src/lib/sci/` |
| Feature flags | `urma-next/src/lib/use-features.ts` |
| MongoDB routes and auth | `urma-next/src/app/(authenticated)/_common/api/mongo/`, `src/lib/security.ts` |
| Provider hierarchy | `urma-next/src/app/(authenticated)/providers.tsx` |
| E2E tests | `urma-test/tests/` |

Key abstractions: **Rest** (HTTP singleton with tenant headers), **SCI/RCI**
(XML device communication), **useV1Api** (paginated SWR hook), **useMongo**
(MongoDB preferences).

## Change impact checklist

- **API contract?** Check endpoint, hook, types, pagination, cache key,
  mutation invalidation. Verify loading/empty/error states. Verify account
  switching isolates results. For list pages, verify overlapping cache keys
  all get invalidated -- partial invalidation leaves stale rows.
- **Background error visibility?** Force a 500 during background revalidation.
  Prove the user sees a visible failure, not silently stale data.
- **Multi-step form?** Check initialization, edit-mode rehydration,
  `revalidateOnFocus` + `enableReinitialize`. Verify unsaved edits survive
  revalidation. Verify create/edit preserve step state.
- **Tenant scope?** Check Actor/Account-Filter injection, MongoDB filters.
  Verify account switch doesn't leak stale rows. Verify writes land in the
  selected account.
- **Account switch?** Verify cache invalidation covers all account-scoped
  hooks. Verify header change propagates before refetch. Verify no component
  retains stale context from prior account.
- **Authentication?** Expire a session mid-use. Prove page load, navigation,
  and API requests all fail and recover. Test both OAuth/JSession paths.
- **Device operation?** Send with `cache` true and false. Prove both paths
  produce correct UI state.
- **Provider/context?** Change order only if you can prove account changes
  still reseed cache and consumers don't retain stale context.
- **New page?** Prove first fetch runs with correct account scope and focus
  revalidation can't overwrite unsaved state. Three-layer pattern. Identify
  failure archetype.

## Key architectural facts

- URMA is a frontend proxy for DRM. The browser never talks to DRM directly.
  Business data and device connectivity live in DRM.
- Hard problem: the selected account must scope every fetch, every write,
  every cached result -- while background revalidation and local form edits
  proceed independently.
- Two governing flows:
  - **Load:** route -> providers (Auth blocks on session, Cache creates
    account-scoped DiskCache) -> SWR fetch. First fetch can race before
    useAccount establishes the real account filter.
  - **Save:** Formik -> Rest (tenant headers) -> middleware (auth) -> DRM ->
    SWR mutate -> re-render -> Formik reinitialize risk.
- Account switch: Rest.setAccountFilter -> listener -> new DiskCache keyed to
  new account in IndexedDB -> SWR revalidates. Cache swap before refetch.
  Stale closures and late responses from prior account are residual risks.
- Pages: server page.tsx -> client-wrapper (ssr:false) -> actual page with SWR.
  No server-side data fetching in examined pages.
- Server traffic splits: middleware proxies /api/ws/* to DRM; route handlers
  under _common/api/ serve MongoDB (same NextAuth JWT, authorizedForRequest
  + userFilter for scoping).
- Errors: 401 -> centralized sign-out. Save failures -> FlashMessage. Background
  revalidation failures -> silent stale data (per-component, no global handler).
- Tenant headers: GETs get Account-Filter, writes get Actor (edge-case
  overrides exist). Wrong headers = silently wrong data if DRM accepts them.
- Authorization: four layers -- middleware, DRM, provider role gating, flags.
- Releases: release/YY.MM.DD, GitLab CI -> Docker -> FluxCD -> K8s.
