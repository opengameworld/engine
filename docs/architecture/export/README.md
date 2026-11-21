# Export and deploy: output contract first (synthesized design)

> **Status: proposal for review. No code yet.** Nothing here runs or is imported. Implementation starts only after Isabella reviews this design.

Sketch files are under `sketch/`. Each path inside `sketch/` is the path the file would have in the engine repo, with `.txt` appended so that `bun run check` (and its upcoming auto-discovery of `.bend` files) never compiles a sketch. Bend bodies are `TODO` and TS bodies `throw new Error("not implemented")`, with the logic written as pseudocode in comments.

How this design was made (AGENTS.md workflow): three read-only explorations (the web build and EXPORT.html, the native track in bend-engine/bend-gpu/bend-win, and external research on Unreal, Unity, Gregory and the hosts). Then two structurally different designs: "output contract first" (this one) and "own the publish platform" (content-addressed store, a publish daemon, channel pointers). An independent judge scored them, and this one was taken as the base with four ideas grafted in from the other. See "Synthesis decision".

Unverified claims are marked [U].

## Problem

Caio owns export and deployment, and the goal is "an experience similar to Vercel": one command, a link that is safe to share, going live on purpose, and easy rollback. The engine already makes a static web bundle (`bend index.html -o dist`, about 48 KB gzip), so putting it on a host is easy. The hard part is that nothing currently says what a game *is* once it leaves the repo. Five facts make the shape non-obvious:

1. The only page is the editor (`main.js` calls `startEditor`). `dist/` ships `editor/` code today.
2. "Runtime never imports editor" is a convention. Only `refs/` is fenced. `engine/world.bend` and `engine/gizmo.bend` already import Bend-UI tokens.
3. The team rule says every rule, number and decision lives in `.bend`, and JS only reads input and draws. Cache policy, budgets, "may this ship?" and "who may go live?" are decisions, so they have to be Bend, with laws in `LAWS.bend`/`PROOF.bend`.
4. Bend 2.0.40 does no IO in pure code (CATCHES X6). Proofs are structural (F1, F6), `match` only works on parameters (M1), and there are no forward references (R1). Export laws have to be shaped so they reduce.
5. The other owners have work coming: Isabella's `engine/input/`, `tick.bend`, `play.bend`, depth and draw order, and `check.ts` auto-discovery. Vini owns shaders, post and `draw.js`. Export must plug in around that work, not over it.

The building has to happen on our machine or our CI, because it needs `bend` 2.0.40 plus the sibling `../bend` clone. That rules out "let the host build it".

## Usage (caller's view)

### Quickstart (README section "Publish")

```sh
bun run export web --project character    # check -> bundle -> out/web/character/ (or the refusal reasons)
bun run export serve                      # play it on localhost with the same headers every host sends
bun run deploy vercel                     # export + publish a PREVIEW; prints its own permanent link
bun run deploys vercel                    # history, newest first, live one marked
bun run promote vercel 3c9e0a71b2d4       # a person makes that build live (asks you to type the id back)
bun run rollback vercel                   # the build before the live one goes live again
bun run deploy vps                        # same five verbs on a VPS (Caddy) and on itch
```

What comes out is always the same folder, whatever the host (`sketch/example/tree.txt`, `game.json`):

```
out/web/character/
  game.json            manifest: format, build id, game, engine commit, dirty, isolation, entries[path, kind, bytes, gz, sha]
  site/index.html      the only Page            -> revalidated on every load
  site/_/*-<hash>.js   Code (bundle)            -> immutable, cached for a year
  site/a/<hash>.*      Asset (format 2, later)  -> immutable
```

A refused export writes no folder and prints the reasons:

```
$ bun run export web
refused: editor code reached the game: editor/app.js
refused: first load 412 KB gzip is over the 300 KB budget
```

### Call sites

1. **A person shipping a fix.** `bun run deploy vercel` prints `preview https://ogw-character-k2j3.vercel.app (build 3c9e0a71b2d4)`. They play it and then run `bun run promote vercel 3c9e0a71b2d4`. If a player reports a bug, `bun run rollback vercel` puts the old build back.
2. **An agent asked to "publish the game".** It runs `bun run deploy vercel --json` and gets `{"ok":true,"deployment":{"buildId":"3c9e…","url":"https://…","live":false}}`, then reports the link. If it tries `bun run promote … --json`, the result is `{"ok":false,"reasons":["only a person makes a build live"]}`, because `Hosts.may_promote(Agent{}, m) == NotAPerson{}` is a law. The future MCP server (`export/mcp.ts`) wraps these same four functions, so there is no second path.
3. **CI on every push (later).** The job checks out `engine/` and `bend@v2.0.40` side by side, installs `bend`, and runs `bun run deploy vercel --json`. It comments the preview link on the PR. Promotion stays manual.

In code, the CLI is the only importer of export (`sketch/export/cli.ts.txt`):

```ts
const r = await exportWeb({ project: "character" });       // { ok, folder: { dir, site, buildId, manifest } } | { ok:false, reasons }
const d = await deploy("vercel", { project: "character" }); // { ok, deployment: { buildId, url, live:false, at } }
await promote("vercel", d.deployment.buildId, { actor: "person" });
```

## Shape

### Engine-wide layer map (`sketch/LAYERS.bend.txt`)

```
                ships in a game                                         never ships
  ┌──────────────────────────────────────────────┐      ┌────────────────────────────────────────┐
  │ projects/ (Project) ─┐   PROJECT.bend (Catalog)│      │ editor/, index.html, main.js (Editor)  │
  │                      ▼          │              │      │ export/   (Export: reads Catalog)      │
  │ engine/ (Engine: pure Bend) ◄───┘              │◄─────│ tools/, tests/ (Tools, Tests)          │
  │   input/ tick play  ◄ Isabella                 │      │ refs/  (Refs: dead end, nothing in)    │
  │   shader/ material  ◄ Vini                     │      └────────────────────────────────────────┘
  │   place world scene …                          │      later, ships to a SERVER, not the client:
  │        ▲                ▲                      │        server/ (pure Bend rules of the world)
  │ platform/web (PlatWeb)  platform/native        │        platform/server/ (Bun WebSocket shell)
  │  draw gpu input loop run game.html             │        both import engine/: same rules client & server
  │ node_modules/bend-ui (UiKit)                   │
  └──────────────────────────────────────────────┘
```

The rules are in one Bend file, `LAYERS.bend`: `layer_of(path)`, `may_import(a, b)` and `ships(l)`. Three laws come with it: only refs imports refs, nothing that ships imports the editor, and only tools, tests and export import export. Each is a case split over a finite enum, so it can be proved with `{==}`.

The rules are enforced in two places, not left as convention:

- **Every `bun run check`.** The fence step (`sketch/tools/fence.ts.txt`) replaces today's refs-only fence. It walks the files Isabella's auto-discovery finds, extracts import edges, and asks `LAYERS.bend` about each one. A new rule is one line in Bend.
- **Every export.** `Contract.release` gets the files the bundler actually read (Bun.build `metafile`) and refuses any input from a layer that doesn't ship (`Forbidden{path}`). This catches edges the text scan misses.

Where the other owners plug in, with nothing about their design changed:

- Isabella's `engine/input/`, `tick.bend` and `play.bend` are layer Engine.
- `input.js` delivering events stays PlatWeb.
- Her work also fills the body of the new `platform/web/run.js` `runGame(canvas, game)`. That is the player's counterpart of `startEditor`. Export depends only on its signature.
- Vini's `engine/shader/` and `material.bend` are Engine, and `draw.js` is PlatWeb. Shaders are strings written at runtime, so there is nothing for export to condition yet. Precompiled shader variants would later become manifest entries of a new `Kind`.
- Draw order from Bend has no export impact.
- The Bend-UI token import from `engine/` is allowed explicitly as named debt (Engine -> UiKit). Whether `gizmo.bend` moves to `editor/` is Isabella's call.

### The contract (`sketch/export/contract.bend.txt`): data first

- `Entry{path, kind: Page|Code|Asset, bytes, gz, sha}`: one served file.
- `Manifest{format, game, title, engine, dirty, isolation, entries}`. It has no timestamps and no machine names, so the same sources give the same manifest.
- `Facts{game, title, engine, dirty, isolation, inputs, files}`: everything the shell *measured*, with no decisions in it.
- `release(checks: Bool, f: Facts) -> Shipped{Manifest} | Refused{List<Reason>}`. `Reason` is ChecksFailed, Forbidden, NoPage, TwoPages, Unhashed or OverBudget.
- `cache(kind)` and `headers(isolation, kind)` set Cache-Control, nosniff, and COOP/COEP only when isolation is on. `id_text(m)` is the canonical text the shell hashes into the 12-hex build id. `json(m, id)` produces game.json. `missing(m, present)` is used by verify.

How the main access patterns go through it:

- **Export:** the shell measures `Facts`, `release` decides, and the shell writes `site/` and then `game.json` last into `.stage-<pid>/`, renamed into place in one step. A crash leaves a stage with no game.json, which every reader refuses.
- **Deploy:** `verifyFolder` parses game.json into a Bend `Manifest` once, at the boundary. `Hosts.fits(host, m)` is checked before any upload. The adapter translates (`Hosts.vercel_config`, `Hosts.caddy_site`) and uploads.
- **Promote:** `Hosts.may_promote(actor, m)` must return `Allowed`. `Hosts.previous(history, live)` picks the rollback target.

Where invariants live:

- **"Nothing ships if a law fails"** is encoded in the order of `release`'s match. `checks` is matched first, so `release(False{}, f) == Refused{[ChecksFailed{}]}` holds by reduction for every `f` and is a provable law, not a test. The same trick makes `may_promote(Agent{}, m) == NotAPerson{}` a law.
- **"Every manifest entry exists"** holds by construction, because the manifest is *derived* from the files on disk, never written separately. `missing()` re-establishes it after copies and uploads. It is a numeric test in `tests/export.bend`, because list walks over Strings don't reduce in proofs (F6-like).
- **"No editor/refs code inside"** is enforced by LAYERS plus `Forbidden`, as above.
- **Single source of truth for history:** the host. That means Vercel's deployment list tagged with `--meta ogwBuild=<id>`, the VPS's `releases/` folder plus the `live` symlink, or itch's butler channel. There is no local ledger to drift.

Idempotence: the build id is content-derived. Running export twice gives the same folder. Publishing a build id the host already has returns that deployment. Promoting the live build does nothing.

### The hosts (`sketch/export/hosts.bend.txt`, `publish.ts`, `hosts/*.ts`)

The TS `Adapter` interface has three methods: `publish` (preview, idempotent), `promote` and `history`. Only `publish.ts` uses it. Hosts *translate*: header policy is decided once in `contract.bend` and written into each host's dialect by `hosts.bend`. Host limits are numbers in Bend (`limits(h)`), so a misfit is refused before upload.

| | Vercel | VPS (Caddy) | itch |
|---|---|---|---|
| Upload | `vercel deploy --prebuilt` of `.vercel/output/` (config.json + static/) | `rsync --link-dest` into `releases/<id>.part`, then rename and `.done` | zip, `butler push --userversion <id>` |
| Content-hash dedup | Vercel's own | hard links to unchanged files | butler patches |
| Preview link | each deployment's URL | `<id>.preview.<domain>` (own origin) | none (local `export serve`) |
| Live = pointer | `vercel promote` | `ln -sfn` + `mv -T` (atomic) | a push is live |
| Rollback | promote previous | swap symlink back | push previous zip |

Interface depth: the public surface is four functions (`exportWeb`, `deploy`, `promote`, `rollback`, plus `deploys` to read). Behind it sit the check run, the bundling and naming, hashing, the verdict, the atomic write, layer enforcement, host translation, limits, idempotent upload and the promotion gate. Callers never see stages, config formats, symlinks or CLI flags of a host. Adding a host means one `hosts/x.ts` with three methods, plus Bend `limits`/translation cases that the compiler forces through exhaustive matches.

What it deliberately does not do: build on the host, precompress (`.br`/`.gz` never enter the folder), keep a local deployment log, edit server config remotely (the Caddyfile is printed and a person installs it once), or touch `editor/`.

### The game page (prerequisite)

`platform/web/game.html` plus a two-line `game.js` import the virtual module `ogw:game`. Export generates that module as three lines: `import P from PROJECT.bend; p = P.by_id("character"); export {id, title, opening, camera}`. The game page then calls `runGame`.

Project ids and lookup (`id`, `all`, `find`, `by_id`) go into PROJECT.bend (`sketch/PROJECT.additions.bend.txt`), because they ship. The law `every_project_is_findable` keeps `all()` honest. Per-game host settings sit in `export/games.bend`, with an exhaustive match over `Project`, so there is no second list.

## Is deploying to Vercel or a VPS feasible? (evidence-based answer)

**Vercel: yes, today, for the game as it is.** The output is static, about 48 KB gzip, with no WASM and no server code.

What is needed:

- A Vercel account and project.
- `VERCEL_TOKEN` for agents and CI.
- Our build on our machine or CI, because the build needs `bend` 2.0.40 and `../bend`.
- The adapter writes the Build Output API folder (`.vercel/output/config.json` v3 plus `static/`), and `vercel deploy --prebuilt` uploads it. Previews, immutable deployments, `vercel promote` and rollback are all native Vercel features. That is the "Vercel experience" with no engine-side service at all.

Constraints:

- **Hobby plan:** non-commercial use only. It allows 100 GB of transfer a month, 100 deploys a day, 100 MB per CLI upload (Pro: 1 GB) and 15,000 files.
- **Header rules count as routes** (2,048 maximum), so we write one rule per Kind, never one per file.
- **Previews are behind Vercel login by default** under Deployment Protection [U]. Turn that off for previews or use share links if players should open them.
- **Transfer becomes the cost once assets arrive.** At 50 MB of assets per new player, 100 GB is about 2,000 cold sessions a month. Format 2 therefore gives assets their own base URL, so big files can move to R2 (no egress fees) or another CDN while the page stays on Vercel.

What Vercel cannot do: host the persistent world. Functions can now hold WebSockets, but each connection ends at the function's maximum duration (300 s on Hobby, up to 800 s on Pro). Instances also share no memory and scale to zero. That is fine for presence or chat, and wrong for an authoritative simulation.

**VPS: yes.** It needs a Linux box, a domain, Caddy (automatic TLS), an SSH key and rsync. The adapter itself is the release convention (`releases/<id>/`, the `live` symlink, path previews). A VPS gives up the global CDN, so put Cloudflare in front when players are far away. In return it can also run the future world server on the same domain and certificate (`reverse_proxy /ws`).

**Not possible or not viable:**

- Raw UDP from a browser. Browsers offer WebSocket, WebTransport or WebRTC.
- Pixel Streaming at scale, because each session needs its own GPU instance.
- Web threads without COOP/COEP on every page. The contract has an `isolation` flag for that, off by default, because turning it on breaks third-party embeds.
- Native builds through this pipeline today. There is no packaging, no signing or notarization, and Mac arm64 only.

**The persistent multiplayer world later.** Two deploy units:

1. The static client, through this same contract, on Vercel or the VPS.
2. A long-lived server: `server/` holds pure Bend rules that import `engine/` (the same rules the client predicts with), and `platform/server/` is a Bun WebSocket shell, or later native Bend→C on Linux (Base has TCP). It runs on a VPS or any container host, never on Vercel Functions.

The contract grows one field in format 2, `server: {protocol}`, plus a Bend law `compatible(client, server)`. Deploy then refuses a client whose protocol the live server doesn't speak. Server releases reuse the VPS convention (`releases/<id>`, `live`) with a process restart instead of a symlink swap.

## AGENTS.md decision workflow, applied

| Source | Taken | Rejected |
|---|---|---|
| **Unreal** (cook -> stage -> package -> archive; pak/IoStore; ChunkDownloader; Server target) | A staged, archived build as its own artifact separate from the editor (our `out/web/<game>/`). A manifest beside the files (ChunkDownloader). A separate server target (`server/` + `platform/server/`). | Pak/IoStore containers on the web: browsers and CDNs cache per file, and one big archive defeats incremental updates. Pixel Streaming: cost per player. No first-party web target to copy. |
| **Unity** (Build Profiles; WebGL `Build/` folder; Addressables catalog + hash + remote load path; dedicated server build) | Per-target settings as data (`export/games.bend` `Settings`). A catalog with hashes (game.json). Remote load path, which becomes format 2's asset base URL for an object store. | The WASM runtime (2–10 MB vs our 48 KB). Precompressed `.br` builds that need exact Content-Encoding headers or a slow JS fallback: hosts compress instead. |
| **Gregory**, *Resources and the File System* [U] | The runtime/tools split, so export is a tool that never ships (a LAYERS law). Deterministic, hashed builds with a manifest. Content hash as the resource identity. An offline conditioning pipeline as a separate step (format 2 Asset entries, incremental by source hash). | Packing everything into a few archives: right for discs and consoles, wrong for HTTP/2 CDNs. |
| **Bend conventions** (2.0.40, CATCHES) | Decisions in `.bend`, IO in the shell (effects as data, X6). Laws only where they reduce structurally (match order makes `release`/`may_promote` laws provable). List walks go to `tests/*.bend` `checks()` (F1, F6). Exhaustive matches over `Project` instead of second lists. No forward refs or mutual recursion in the sketches. Helpers for computed matches (M1). | Bend producing files or calling hosts (no IO in pure code). Runtime `~` templates keyed on project ids (Q13). |
| **Vercel** (the requested experience) | Build Output API: literally our Vercel target, and the model for our own contract. Immutable deployments, previews, promote and rollback as pointer moves. Agents deploy previews and only people promote. CLI, then MCP over the same functions. | Building on the host's machines. Using Functions for the world. |
| **Performance and reach** | A first-load budget law: 300 KB gzip before the first frame, about 6× today's page and about 7× smaller than a tuned empty Unity build. Immutable caching for everything but the page. WebGL2 (~98% reach). Isolation off by default so embeds on itch and portals keep working. | Anything that adds a runtime download to the critical path (WASM loaders, decompression fallbacks). |

## Synthesis decision

**Base: candidate 1 ("output contract first").** It won independently twice: my rubric reading and an opus cross-judge (24/30 vs 22/30). It answers today's question with the least to build and run: one folder contract, thin host adapters, Vercel's own previews/promote, no service to operate. It respects ownership best (`runGame` is a signature Isabella fills; nothing touches Vini's draw/shader code) and its first slice is small and visible. Candidate 2's publish platform stays reachable later as one more adapter that reads the same folder.

**Grafts from candidate 2 (folded in by hand):**
1. **Layer debts + closure check** (`sketch/LAYERS.bend.txt`): no blanket Engine→UiKit allowance; the three real token imports are named `debts()`, a paid debt fails the check, and `stowaways()` checks the whole import closure of `game.html`.
2. **Actor from the credential + provenance that travels** (`contract.bend` `Source{commit, dirty, checked}`, `hosts.bend` `Robot{}`, `UncheckedBuild{}`): agent and CI tokens are preview-only at the host; laws `robots_never_promote`, `dirty_never_goes_live`, `unchecked_never_goes_live`. game.json is also served at `site/game.json`, which fixes the base's gap (promote/rollback could only check the last local export).
3. **`target` and `seed` in the manifest from format 1** (`Target = Web | MacArm64 | WinX64 | WorldServer`): native builds and the world server need no format change; the seed is checked on promote (AGENTS.md: it never changes). Protocol/schema fields come with the server (format 2).
4. **Previews on their own origin on the VPS** (`<id>.preview.<domain>`, not a path): localStorage/IndexedDB are per origin, so a preview never touches live players' saves. (Vercel previews already have their own origins.)

**Fixes the judge found in the base:** `type Kind` is a Bend keyword (CATCHES N4), renamed `Role`; `bun run build` is NOT removed (shared script; it stays the editor demo build).

**Rejected from candidate 2, for now:** `shipd` daemon with tokens and passkeys, the append-only log, sweep/pin, `<base href>` doors and wildcard on-demand TLS. Too much to run for a team this size before there is a game; and doors depend on an unverified Bun assumption. Its `fits_world` law was also false as stated (seed checked before schema).

## Tradeoffs accepted

- **One more file for `export web` to write, in exchange for "if it plays locally it plays everywhere".** The game folder plus game.json is a contract we must version (`format`), and it buys host independence: three adapters with three methods each.
- **Every project is compiled into every game until projects get their own entry files, in exchange for no generated per-project Bend.** Today that means a few KB.
- **The build always happens on our side, in exchange for one toolchain everywhere.** Pinned Bend, and the bundle that passed the laws is exactly the bundle served. Vercel's "push and it builds" convenience comes back only through CI.
- **No local deploy history, in exchange for no split ownership.** `deploys` costs a host call, and history is only as rich as the host keeps it.
- **The promotion gate is ours, not the host's, in exchange for one rule across hosts.** It stops a well-behaved agent. It does not stop a token holder who bypasses the CLI.
- **Two build commands live side by side: `bun run build` (the editor demo, shared script, unchanged) and `bun run export web` (a game).** Only the second may be deployed by `deploy`.
- **Bend writes JSON and Caddyfile text by string concatenation, in exchange for keeping every policy in Bend.** It is a little verbose.

## Alternatives considered

- **Host-first (a "deploy" command per host, each building its own way).** It has the smallest initial code and the shallowest interface: every host repeats bundling, header policy and the laws. Each new host is a new chance for editor code or a wrong cache rule to ship, and the laws would have to be re-proved per host. Rejected because of information leakage across adapters.
- **Our own publish service (EXPORT.html step 4 taken literally): a store keyed by content hash, a deployments database, an alias API, our own CDN.** It has the deepest interface and is fully Vercel-like on any machine, but it hides a whole service we would have to run and secure before there is a game to ship. The contract-first shape keeps that option open: such a service would be just one more adapter reading the same folder.
- **Pack the game into one archive (pak-style) with a JS loader.** It gives atomic versions, but it loses per-file CDN caching and incremental updates, and adds a loader to the critical path. It is right for native and console later, wrong for the web.

## Open questions and risks

- Should `runGame`'s body be Isabella's from the start, or should export land a minimal draw-only version that she replaces when `tick.bend` and `play.bend` arrive?
- Is a person typing the build id back on a TTY enough of a promotion gate, or should we also split host credentials (a preview-only token for agents and CI, the promote token only on a person's machine)? The latter is the real wall.
- Does `vercel promote` of a preview move a pointer, or rebuild? The pointer-only path may be `deploy --prebuilt --prod --skip-domain` then `promote`. [U] Test before relying on it.
- Does Bun's HTML bundling honor `naming.chunk`/`naming.asset` (`_/`, `a/`), emit relative URLs (needed for path previews on the VPS), and offer `metafile` in the pinned Bun? [U] If not, path rules move to a post-build rename, and inputs come from a walk of the import graph.
- Is the game going to be commercial before a Pro plan? Vercel Hobby forbids commercial use.
- Should `gizmo.bend` (and the Bend-UI token import) leave `engine/`? LAYERS allows it today as named debt.
- What does Vercel's Deployment Protection default to on the team's account? It decides whether preview links are playable by outsiders.
- Native (format 2, `app/` instead of `site/`) needs executable-relative asset paths in bend-engine, which loads relative to the working directory today. Should that become a barrier in `docs/barriers.md` now?

## Next implementation step

Write `export/contract.bend` (`release`, `cache`, `headers`, `id_text`, `json`) with its two laws and `tests/export.bend`. Then `export/web.ts` `exportWeb` on `platform/web/game.html`, so that `bun run export web` produces `out/web/character/` with a valid game.json, which `bun run export serve` plays.
