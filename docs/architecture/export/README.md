# Export and publish, revision 2: the release protocol is the spine

> **Status: proposal for review. No code yet.** Revision 2 of the export design, after Isabella's review of revision 1 (PR #2, 2026-11-22). Revision 1 is in this file's git history.

It revises the approved revision 1 and keeps what survives. How it was made: two structurally different designs, scored by an independent judge who also re-measured the sizes; this one is the base, with four ideas grafted from the other (see "Synthesis decision"). Sketch files are under `sketch/`, at the paths they would have in the engine repo, with `.txt` appended. Bend bodies are `TODO` and TS bodies `throw new Error("not implemented")`. Nothing here runs.

Marks: **[R]** = read this session by me. **[G]** = read this session by the grounding pass (`grounding.md`), not re-read by me. **[MEM]** = remembered, not read. **[U]** = unverified, and a slice verifies it. **[M]** = measured this session (by a design runner or by the judge, who re-measured on the real page path).

## Problem

Part 1 of Caio's work is the engine's `next build`: a command that turns a project into a game folder that any host can serve. It now has to fit a larger product, in the words of Isabella's binding review: *anyone* who makes a game with this engine publishes it and gets a link under our domain, with no Vercel account, no server and no token of their own. The service is not built yet. It has to be designed now, so that it becomes the next adapter and not a rewrite. The first slice stays as approved: `export/contract.bend`, its laws, `tests/export.bend`, `bun run export web` and `bun run export serve`.

These constraints make the shape non-obvious:

1. **Bend decides, TS only does the work.** Every rule, number and decision lives in `.bend` with laws. TS measures, bundles, hashes, writes and uploads. Nothing a person sees is hand-written HTML, CSS or JS. The game page is a canvas, and anything around it is a Bend-UI page.
2. **VPS first, and the game is commercial.** Nothing may depend on Vercel Hobby.
3. **Going live needs split credentials and a typed confirmation.** An agent's or CI's key writes releases. Only a person moves the live pointer, and only after typing a confirmation.
4. **The real sizes break v1's budget numbers** [M]. The Character game's Bend compiles to 162 KB raw / 20 KB gzip. The mannequin's assets are about 1.28 MB on the wire. `motions.bend` is one 3.8 MB file holding all 42 clips. With plain `bend x.bend -o x.js`, Bend drops defs nothing names (one named clip: 606 KB raw / 51 KB gzip; all 42: 34.5 MB / 2.53 MB). **But on the path a page really takes (Bend's loader plugin + Bun's bundler), the loader exports every def, so naming one clip still ships all 42: 9.5 MB raw / 1.93 MB gzip** [M, judge]. A file holding only one clip's defs costs ~192 KB raw / ~39 KB gzip on that path [M]. So a game can only take the clips it uses if the library is **one file per clip**, a change to `tools/clips.ts`, which is Isabella's area (see Slice plan: a request to her).
5. **Credits are a legal duty.** The mannequin is CC BY 4.0 and its credit must travel with it. The character itself is © Square Enix / Disney, and CC BY does not clear that.
6. **Bend's own limits** [R, CATCHES]:
   - no IO in pure code;
   - `match` only on parameters;
   - no forward references and no mutual recursion;
   - laws only where they reduce structurally;
   - Base reserves constructor names (`Key`, `Move`, `Done`, `Text`, `Empty` …). I checked every name in these sketches against `base.bend`.
7. **Bend-UI's `Web.bend` has no network command** [R: its own "Limits now"]. So the editor's Publish action cannot talk to anything yet.
8. **Build requirements are real.** The build needs `bend` 2.0.40 and the `../bend` loader. HLSL needs `dxc` and `spirv-cross`. Today `check` passes silently when they are missing.

## Usage (caller's view)

### README, "Publish a game"

```sh
bun run export web character          # check -> walk -> bundle -> out/web/character/  (or the reasons, with the remedy)
bun run export serve character        # play it on localhost with the exact headers the publish host sends

bun run publish push character        # export + upload a RELEASE; prints its permanent link
#   release 3c9e0a71b2d4  https://3c9e0a71b2d4--character--ogw.PLAY
#   code 190 KB raw / 28 KB gz · assets 1.28 MB · credits: mannequin (CC BY 4.0)
#   warning: the mannequin's character is (c) Square Enix / Disney: not cleared for sale
bun run publish promote ogw/character:live 3c9e0a71b2d4
#   live: 9a01ffe4c7b0 -> 3c9e0a71b2d4   (code +2 KB, assets same, credits same)
#   Type "ogw/character:live 3c9e0a" to make it live: ▌      Point secret: ▌
#   live  https://character--ogw.PLAY
bun run publish rollback ogw/character:live     # the same confirmation; back to what was live before
bun run publish history character
bun run publish keys new --for agent --games character --days 7   # a person mints an upload-only key
```

The output is always the same shape. You get one folder (`sketch/example/tree.txt`, `game.json`), one release per distinct content, and three kinds of link, each its own origin under the **play domain**:

| Link | Shape | Notes |
|---|---|---|
| Live | `https://<game>--<creator>.PLAY` | |
| A channel | `https://<channel>--<game>--<creator>.PLAY` | e.g. `beta--character--ogw` |
| One release | `https://<id>--<game>--<creator>.PLAY` | forever |

The creator is never written in the game's source. It comes from the key, so a fork publishes under its own name.

### Call sites

1. **A person on the team's VPS (Caio, today).** The commands above. `promote` shows what changes, asks for the typed confirmation and the person's *point secret*, and sends both. The server checks both again. The point secret is typed at the prompt with echo off and never stored by the client.
2. **An agent or CI.** It runs `OGW_PUBLISH_KEY=ogwa_… bun run publish push character --channel beta --json` and gets `{"ok":true,"released":{"id":"3c9e…","url":"https://3c9e…--character--ogw.PLAY","channel":{"name":"beta","url":"https://beta--character--ogw.PLAY"},"warnings":[…]}}`. Named channels are open, so the agent keeps `beta` fresh by itself. If it tries `promote … :live`, it gets `{"ok":false,"denied":[{"code":"NotAPerson"}]}`. That refusal comes from the server (`sketch/example/wire.txt`), and the law `agents_never_go_live` proves it. With no key and no TTY, the client refuses instead of starting a login (butler's rule [G]).
3. **The editor's Publish tab (`sketch/editor/publish/view.bend.txt`).** It is a fourth tab after Scene | Animation | Shaders, written in Bend with Bend-UI, and it offers exactly the CLI's verbs:
   - **Upload release** shows progress and then the link.
   - **Make live** shows the change, a field to type the confirmation (the button is enabled only when `Pr.confirm_text` matches), and the secret field.
   - **Roll back** uses the same confirmation.
   - **History** lists the releases.

   The page sends commands to the dev server, which calls `publish/client.ts`, the same functions the CLI calls. So the browser never holds a key and there is one client. It waits on Bend-UI's missing network command (Open questions).

4. **A creator on the future service (Ana).** She runs `bun run publish login`. This is Bend's own device flow, as `bend login` does it [R]: a browser page, then polling, then a 0600 key file. Then `bun run publish push forest` returns `https://3c9e…--forest--ana.PLAY`. `promote ana/forest:live …` opens an approval page on the service, where she types the confirmation while logged in. Her commands are the same as Caio's.

The TS API is what the CLI and the dev server import (`sketch/publish/client.ts.txt`):

```ts
const r = await push({ game: "character", channel: "beta" });   // {ok, released:{address,id,url,created,channel?,warnings}} | Refusal | Denied
await promote({ to: "ogw/character:live", id: r.released.id }, presence); // presence: TTY prompt, editor fields, or browser approval
```

## Shape

### 1. One spine: a protocol, spoken by every host (`sketch/publish/protocol.bend.txt`)

`export` makes a folder, and everything after that is one versioned protocol. It has four write steps and a read. They are the same steps BendHub uses for `bend --publish` [R: `bend2/main.ts`: publish-check, then POST content answered by its hash, then `/link name@version → hash`], and the same steps butler uses [G]: validate, upload, finalize, and a channel that points at a build.

| Step | Wire | Credential | Idempotence |
|---|---|---|---|
| have | `POST /v1/have {game, shas}` → `{missing}` | Upload | pure read; blobs are stored **per creator**, so no creator can probe for another's files |
| blob | `PUT /v1/blob/<sha>` | Upload | content-addressed; the server hashes the body |
| release | `POST /v1/release {game, manifest}` → `{id, url}` | Upload | id is the server's hash of the content; a repeat returns `created:false` |
| point | `POST /v1/point {to, id, expect, confirm, presence}` | Open channel: Upload. Live: a person present | `expect` is compare-and-swap; the same id is `NoChange` |
| history | `GET /v1/history` | Read | — |

**The VPS is the smallest server for this protocol, and the service is the same server.** `publish/server.ts` runs in one of two modes, read from its config file:

- **`Team{creator:"ogw"}`:** person secrets are set on the box, and there is no login.
- **`Service{}`:** adds browser login, approvals and quotas.

No verb, address or rule differs between the modes. The client never learns which one it is talking to, apart from handling a `202 {approve_url}` that only the service sends. That is how the service becomes the next adapter rather than a rewrite. The editor's Publish tab and the CLI are both just callers of `client.ts`.

**One set of rules on both sides.** Every request carries `Ogw-Rules: <n>`, and a client on other rules is refused before anything is decided ("update the engine"). The client runs the same Bend decisions (`service.bend`, `keys.bend`) on the server's view before uploading, so a refusal comes before any byte is sent, and the editor can say why a button is disabled. (Graft from candidate 2.)

### 2. Data first: the types that carry the invariants

**`Contract.Manifest`, format 1 (`sketch/export/contract.bend.txt`).** It is v1's manifest plus four things:

- `Asset` entries with their `origin` repo path;
- `load: Load{code_gz, code_raw, asset_wire}`;
- `clips`;
- `credits`, derived as `credits(works(inputs))` and never written by hand.

The build id follows BendHub's own rule [R]: sha256 over `"<sha> <path>\n"` lines, plus the manifest's content fields, cut to 12 hex because people type it back.

**`Pr.Address{creator, game, channel: Live | Named}`, `Pr.Release`, `Pr.Shift`.** A channel's history is an append-only log of shifts. **The pointer is the last shift** (`pointer(moves)`), and **rollback is `previous(moves)`**, the `from` of the newest shift. The pointer is derived, not stored twice. This follows CapRover's `versions[]` + `deployedVersion` [G] and Coolify's "rollback = re-activate an older deployment" [G], minus the second copy.

**`K.PubKey{creator, holder: Person|Agent|Robot, reach, expires, paused, version}` and `K.Presence = Absent | Typed{secret_ok, confirm} | Approved{person, confirm}`.** These two types are where the review's split lives:

- A **key** is a bearer credential in env or a 0600 file. It reads, uploads and moves *open* channels. A person's key also mints and revokes machine keys.
- **No key moves a guarded pointer by itself**, not even a person's. A guarded move also needs `Presence`:
  - on the VPS, a secret typed now and never stored by the client;
  - on the service, an approval in the browser, where the person is logged in.

Without this split, an agent running in a person's shell could simply read the person's key file and promote.

`may.holder` matches the holder first, so `agents_never_go_live`, `robots_never_go_live` and `machines_never_mint` hold by reduction (`sketch/publish/LAWS.bend.txt`). Keys borrow from Coolify [G]: they expire, can be paused, are scoped to a creator and to some games, carry a checksum in the secret, and are stored only as a hash. From CapRover [G] comes a per-creator `version` for revoke-all.

**`Pr.Guard`.** `guard(Live{}) = Guarded`, and every `Named` channel is `Open`. I remembered rather than read that Steam's `setlive` from steamcmd works for beta branches but making the default branch live is done by a person in the web UI [MEM]. Same idea.

### 3. Links, origins and the two domains

Every link is one DNS label under the play domain: `<a>--<b>[--<c>]`. Names never contain `--`. Lengths are capped so that every label stays ≤ 63 characters (`creator ≤ 20`, `game ≤ 24`, `channel ≤ 11`, so a channel is never mistaken for a 12-hex id). This gives four properties:

- **One origin per game channel and per release.** localStorage, IndexedDB, service workers and cookies of one creator's game are unreadable by another's, and a release preview never touches live players' saves (v1's graft, generalized).
- **One wildcard certificate.** `*.PLAY` via DNS-01 [MEM] covers every link, and adding a creator or a game changes no TLS.
- **One Caddyfile that never changes** (`sketch/example/Caddyfile`). `root /srv/ogw/sites/{label}` serves a symlink the publish server keeps. Players' requests never touch the publish process.
- **The play domain is a separate registrable domain** from the service's (`api.SERVICE`, login pages), and it goes on the Public Suffix List. This follows github.io/github.com and vercel.app/vercel.com [MEM]. A creator's script can then never read the service's login cookie. This matters because the service runs JS that strangers wrote.

### 4. The server's decisions are Bend (`sketch/publish/service.bend.txt`)

For each request, `server.ts` reads exactly what Bend asks for (a `Seen…` value), calls one pure function (`release`, `point`), and runs the returned `Apply{steps}` in order: `WriteRelease`, `AppendMove`, `PointSite`, `Log`. Effects are data (CATCHES X6). One owner writes `/srv/ogw`, and every path comes from a Bend def. Shared state and what happens on races:

- **Blobs** are content-addressed. Two identical writes write the same bytes.
- **Releases** have content ids, so a repeat is a no-op, and the same id with other content is refused (`IdTaken`).
- **Channels** are the only shared mutable state. The hands hold a flock across read-decide-append, and `expect` turns a lost race into `Stale{now}`.
- **`sites/`** is a cache derived from the logs. `reconcile` rebuilds it, so a crash between appending a shift and swapping the symlink is harmless.

**Trust.** The server never trusts the client's sizes or id. It re-measures every blob, recomputes `id_text`, and re-runs `Contract.recheck`. It also recognizes the engine's own assets by sha (`known` works). So a manifest that ships the mannequin's `skin.bin` without its credit is refused even if the client lied. `source.checked` and `source.dirty` are attestations that the server cannot re-derive. The laws `unchecked_never_goes_live` and `dirty_never_goes_live` stop honest clients. A dishonest creator hurts only their own game's origin.

On a guarded move, the server also refuses `SeedChanged` (AGENTS.md: the world's seed never changes once set).

### 5. Export: the walk, per-game clips, budgets, credits, toolchain

- **Selection uses roots plus a dependency walk** (Godot's export filter and dependency walk [G]). The roots are `PROJECT.start(p)` and the per-game declaration `export/games.bend`, an exhaustive match over `Project`, so there is no second list. `export/needs.bend` walks the scene as data:
  - rigged figures give skins, which become Asset entries;
  - imported materials give shader ids, so only those catalog entries ship;
  - declared clip names are resolved to indices.

  Export then writes **a per-game Bend module**, `out/gen/<game>/game.bend`, that imports one file per picked clip (`library/<c>/gen/m/<slug>.bend`). Naming one def of today's `motions.bend` is not enough: on the page path the loader exports every def, so all 42 clips would ship [M, judge]. The split into one file per clip is a change to `tools/clips.ts`, so it goes to Isabella as a request (`sketch/requests/tools-clips-one-file-per-clip.ts.txt`, from candidate 2). Until it lands, a game with library clips is refused `OverCode`, honestly, and games with the code-made idle and walk export fine. Bend decides what is in the module (`Glue`), and TS prints it 1:1, as `tools/clips.ts` prints `motions.bend` today. `out/gen/` is a new layer, `GameGen`, and it ships.
- **Budgets count Code and Assets apart.** The numbers come from one reach rule in Bend: a 1.6 Mbit/s phone link [MEM]. Code blocks the first frame, so it gets 1.5 s; assets do not, so a game is playable within 10 s.

  | Budget | Limit | Character game today | One library clip (page path, minified) [M] |
  |---|---|---|---|
  | `code_gz` | 300 KB | ~28 KB | ~39 KB, so ~6 clips fit |
  | `code_raw` | 2 MB (provisional) | ~190 KB | ~192 KB |
  | `asset_wire` | 2 MB | ~1.28 MB (the mannequin: 64%) | — |

  `code_raw` stands for parse time on a low-end phone. Its number is provisional and is re-measured in slice 3 on the real minified bundle. Each budget number is a law, so changing one is a visible decision. Clips compiled as code are a visible, measured cost instead of a surprise on a phone.
- **Credits.**
  - `Work = Mannequin | Quaternius | BendUi` is a closed list, so a new work makes the compiler point at every match.
  - `credits(works(inputs))` is derived.
  - `attribution(credits_page, works)` matches `credits_page` first. `credits_page` is **measured**: it is true only when `site/credits.html` is really in the folder, never declared by hand (graft from candidate 2). The law **`mannequin_needs_its_credit`** proves that a build with the mannequin and no credits page is refused, whatever else it ships. **`mannequin_credit_travels`** proves the credit is in the manifest.
  - The credit is *shown* on `credits.html`, a page written by Bend from a Bend-UI tree (`sketch/ui/credits.bend.txt`) and turned into static text at export time, so no Bend-UI JavaScript ships for it. The game page itself (`index.html`) is also text written by Bend (`Contract.page`), never a hand-written file.
  - The strings live in `mannequin/credit.bend`, and a test keeps `CREDITS.md` in agreement.
  - The IP question is a `Warning` (`NotClearedForSale`), not a refusal, because the owner chose the mannequin.
- **Toolchain.** `Facts.tools = Toolchain{bend, dxc, spirv_cross}` is measured by TS. Bend refuses `WrongBend` when the version is not the pinned 2.0.40. It refuses `ToolMissing{"dxc", shader}` only for an HLSL shader the game uses, and `ShaderNotBuilt` when the catalog has only diagnostics. A GLSL-only game builds without `dxc` and the CLI says so. Messages name the phase and the remedy, as Godot's missing-template error does [G].
- **Minimal `runGame`** (`sketch/platform/web/run.js.txt`). It does what the review asked for and nothing more: draw the scene, and when `Lo.runs(scene, reduce)` is true, `scene = Lo.frame(scene, input, dt, reduce)`. Isabella replaces the body later, and the signature stays.

### 6. Layers (`sketch/LAYERS.bend.txt`)

These rules are checked on every `check` and on every export, against the bundler's real inputs. **One table, `places()`, is the only list of folders in the engine** (graft from candidate 2): `layer_of(path)`, what ships, and the folders `check` type-checks (`typed_roots()`, which replaces `check.ts`'s hand-written `FOLDERS`) are all derived from it. A folder missing from the table is `Outside`, which the fence refuses, so a new folder cannot stay silently unchecked.

New layers:
- ship: `Mannequin` (with its credit), `Library` (only the clip files a game imports), `GameGen` (`out/gen/<game>/`);
- never ship: `MannequinLaws` (incl. `gen/weights.bend`, 141 KB), `MannequinSource` (`source/`, `gltf/`), `LibraryIndex` (the editor's 42-clip catalog and thumbs), `LibrarySource`, `GameUi` (rendered to static text by export), `Contract`, `Export`, `Publish`, `PlatPublish`.

`editor/workspace/` and `editor/shaders/` are Editor, and `tools/shaders/` is Tools. `engine/gizmo.bend` and `engine/world.bend` stay as named debts; a debt that no longer exists fails the check. Laws: `shipped_never_imports_editor`, `shipped_never_imports_tooling`, `sources_never_ship`, `laws_never_ship`, `publish_rules_never_ship`.

Note: `main.js` (the editor) loads the mannequin's textures from `mannequin/source/`, which never ships. The game's export takes them from there by path, as the bundler does; moving them to `gen/` would be cleaner, but that is the mannequin's owner's call, not export's.

### Interface depth

Callers learn four verbs (`push`, `promote`, `rollback`, `history`), plus `keys`, and one address grammar (`creator/game:channel`). Behind them:

- the check run, toolchain verdict, walk, per-game module, bundling, measuring, budgets and credits;
- content-addressed dedupe, resumable uploads, protocol versioning, key lookup, presence prompts and approvals, compare-and-swap on pointers;
- storage, symlinks, the audit log and reconciliation.

All policy is in four Bend files: `contract`, `protocol`, `keys`, `service`. Adding a host means writing a server that speaks the protocol. The client does not change.

**Red-flag screen:**

- **Two ways to do one task:** the CLI and the editor share `client.ts`. v1's `deploy`/`deploys` scripts are not added, and `build` stays the editor demo build.
- **Hand-synced lists:** the Caddyfile is printed from Bend, `CREDITS.md` is held to `credit.bend` by a test, games are an exhaustive match, and works are derived from layers.
- **Split ownership:** one server owns `/srv/ogw`, the pointer is derived from the log, and `sites/` is a cache.
- **Leakage:** wire JSON is parsed into Bend types in the hands and is never passed on.
- **Importable internals:** a LAYERS law; `server.ts` exports only `serve`.

## AGENTS.md decision workflow, applied

| Step | Source (status) | Taken | Rejected |
|---|---|---|---|
| 1 Unreal | [MEM] Cook → stage → package. BuildPatchTool uploads a chunked, content-addressed binary, then *labels* it (e.g. Live) for a platform. Server target. | Immutable upload, then a separate label move: our release, then point. A staged folder separate from the editor. | Pak archives on the web: CDNs cache per file. |
| 1 Unity | [MEM] Build Profiles. Addressables catalog with hashes. **Cloud Content Delivery**: buckets, content-addressed entries, immutable *releases*, *badges* as named pointers. **Unity Play**: creators upload WebGL and get a link. | CCD is almost exactly our store, releases and channels. Unity Play is the product Isabella describes. | WASM runtime size. Precompressed builds that need exact headers. |
| 1 Roblox | [MEM] Studio's "Publish" creates a place version; version history restores an older one; collaborator permissions. | The editor publishes like Studio. Restore = pointer move. Per-creator permissions. | Its closed, server-built pipeline. |
| 2 Map | Every one of these separates **immutable content** from **a movable name**. They differ in who may move the name. Steam [MEM]: beta branches by tool, default branch by a person on the web. | Open vs Guarded channels. | Host-built pipelines (we must build: `bend` 2.0.40, `../bend`, dxc). |
| 3 Gregory | [MEM] *Game Engine Architecture*: resource GUIDs, an offline conditioning pipeline, an asset dependency graph that the build walks, the runtime/tools split. | Content hash as identity. The needs walk is his dependency graph. Export and publish are tools that never ship (LAYERS law). Clips as conditioned data later. | Packing into few archives (disc-era). |
| 4 Open source | [G] Godot export (presets committed, secrets apart, filter + dependency walk, toolchain errors by phase). Coolify (deployment rows + snapshot hash, abilities, scoped/expiring/rotatable checksummed tokens). CapRover (versions[] + one pointer, tokenVersion). Dokku (SSH keys are all-or-nothing). butler (`user/game:channel`, env > file key, CI never logs in, validate → upload → finalize, ParentBuild). Vercel BOA (the service accepts finished output, never builds). [R] BendHub client in `../bend/bend2/main.ts`: content hash = sha256 of "sha path" lines, then name → hash linking, device login, a key that is refused is forgotten. | All of the above, as cited in Shape. Dokku's lesson is why the VPS gets a protocol server instead of v1's rsync over SSH: SSH cannot tell "upload" from "go live". | Wharf patches (dedupe instead). Docker per app. Git-push building. |
| 5 Bend | [R] CHANGELOG 2.0.40 (`bend --publish`, hub). `main.ts` publish and login. `Web.bend`: Cmd has no network. Base effects include TCP listen/accept/send. CATCHES N1/N13 (I checked names against `base.bend`), M1, R1, X6, F1/F6. | Our id rule = BendHub's. Our login = `bend login`'s. Laws shaped to reduce. Effects as data in the server. Barrier filed, not worked around. Later, the server's hands could be Bend on Base TCP. | JS doing what Bend-UI should do. |
| 6 Performance | [M] Sizes above. Reach rule as numbers. | Code/asset budgets. Clips by name (dead-def removal). Immutable caching. The player path never touches the publish process (Caddy serves files). | Lazy code splitting before measuring the bundler. |

## Synthesis decision

**Base: candidate 1, "the release protocol is the spine".** Two designs were made for this revision. Candidate 1 centers on one versioned publish protocol that every host speaks. Candidate 2 centers on the game as a Bend value (`GAME.bend`) plus one publish state machine run identically by the CLI, the editor and the server. An independent judge scored them 23 to 19 and picked candidate 1, and so did my own reading, for three reasons:
- it stays in Caio's lane: candidate 2 needs a new field in `engine/figure.bend`, a new `engine/game.bend`, a rewrite of `tools/clips.ts` and `library/catalog.bend`, and moves in `mannequin/` and `main.js`, all Isabella's areas;
- its credential split is stronger: a key alone never moves live; live also needs a person present (a secret typed now on the VPS, a browser approval on the service), so an agent that reads a person's key file still cannot promote;
- its evidence was measured; candidate 2 priced clips by gzipped Bend source, which understates the real cost about 2x.

**Grafts from candidate 2, folded in by hand:**
1. **One file per clip** (`sketch/requests/`): required, because the judge measured that on the page path naming one clip ships all 42. It is a request to Isabella, not part of an export slice.
2. **`LAYERS.places()`, the only list of folders**, deriving what `check` type-checks and what ships.
3. **A measured credit gate and Bend-written pages**: credits are shown on a static `credits.html` written by Bend, its presence is measured, and `index.html` is Bend's text too. No Bend-UI JavaScript ships for credits.
4. **One set of rules on both sides**: an `Ogw-Rules` version on every request, the client pre-deciding with the same Bend rules, and blobs stored per creator.

**Fixes found by the judge:** `publish/keys.bend` had a forward reference (CATCHES R1), now reordered; the dead-def-removal claim did not hold through the loader (now one file per clip); budgets re-measured on the real page path.

**Rejected from candidate 2, for now:** `GAME.bend` as a second source of a project's start and camera (it comes back when creators publish from their own repos, as one file that replaces `PROJECT.bend` there, not beside it); refusing commercial builds for the mannequin's IP and Bend-UI's license (kept as warnings: those are the owner's decisions); admin, join and quotas in the machine from day one.

## Tradeoffs accepted

- **We accept running a small server on the VPS in exchange for one protocol on every host.** v1's VPS adapter needed no process, but SSH and rsync cannot split "upload" from "go live" (Dokku [G]). The multi-creator service needs this server anyway.
- **We accept that `checked` and `dirty` are client attestations in exchange for a server that never builds.** On the service, origin isolation and the separate play domain limit the damage a lying creator can do to their own game.
- **We accept typing a point secret on every promote (VPS) in exchange for a wall an agent in the same shell cannot climb.** The service replaces typing with browser approval.
- **We accept that a game fits about six library clips, and none until the library is split into one file per clip, in exchange for honest budgets.** The real fix (clips as data) is named below, not hidden.
- **We accept dropping v1's Vercel and itch adapters in exchange for no Vercel dependency.** A bridge that reads the same folder stays possible.
- **We accept 12-hex ids (48 bits) in exchange for typeable confirmations.** A collision is refused, never overwritten.
- **We accept Bend-UI's tokens shipping through the three named debts until they are paid.** The credits page ships no Bend-UI code (static text), but Bend-UI still has no license, so the question stays open.
- **We accept that `isolation` (COOP/COEP) is refused on the publish host in exchange for one static Caddyfile.**

## Alternatives considered

- **v1's host adapters (rsync + symlink over SSH, Vercel prebuilt, butler).** Each adapter reimplements the confirmation and the rules. SSH keys cannot express "upload only". The service would be a fourth adapter with its own semantics, which is a rewrite in all but name. It exposes host quirks to the publish layer.
- **Server-side builds (git push, as in Dokku and CapRover).** This has the simplest client. But the builder needs Bend 2.0.40, `../bend`, dxc and spirv-cross, and it would run strangers' build code on our box. Vercel's own prebuilt path exists for the same reason.
- **Path links on one origin (`PLAY/<creator>/<game>/`).** No wildcard certificate is needed. But every creator's game shares storage, service workers and cookies, and Bun's relative URLs are [U].
- **Object store + CDN as the blob store from day one (R2 or S3).** It scales transfer, but it is an extra account and an extra bill before there is traffic. The protocol hides it: `blob` and `have` can move behind the server later with no client change.

## Open questions and risks

1. **Mannequin IP.** The mannequin's model is CC BY 4.0, but `mannequin/CREDITS.md` says the character it depicts is (c) Square Enix / Disney. The credit satisfies the model's license; it does not give the right to use the character in a commercial game. Is a game that ships it allowed to be sold, or published on a public service? Today the design warns and does not refuse. One line in `service.bend` would refuse it on public `live` if the owner decides. Another option keeps the rig and swaps the mesh.
2. **Bend-UI has no license** (no LICENSE file, no `license` field). Its tokens reach every game through the three named debts, and creators on the service would ship them too. Can a LICENSE be added to Bend-UI before the first public link?
3. **Bend-UI network command.** Will Bend-UI take `Web.request{method, url, headers, body, on_reply, on_fail}`? The editor's Publish tab waits on it.
4. **Domains.** Can we have two registrable domains (play and service) and submit the play domain to the Public Suffix List? With one domain, would `*.play.DOMAIN` with a PSL private entry plus host-only service cookies be acceptable?
5. **Clips as data.** Should the library store motions as binary Assets (like `skin.bin`), decoded by Bend? That would remove most of the ~192 KB of JS per clip. Like the one-file-per-clip split, it is a change to `tools/clips.ts`, Isabella's area.
6. **Unverified [U] items, each checked in its slice:**
   - `metafile` in the pinned Bun;
   - `Bun.serve` routes with HTML imports;
   - Caddy's `host_regexp` placeholder and the DNS provider module;
   - the parse rate of a low-end phone.
7. **Service policy (before Service mode).** Quotas and price, takedown and abuse reporting for strangers' pages on our domain, and account recovery.
8. **The editor's Publish tab: where it goes.** The sketch makes it a fourth workspace tab after Scene, Animation and Shaders. It is new UI, so its placement needs a yes before it is built.
9. **The mannequin's credit strings** (`mannequin/credit.bend`) are a small new file in `mannequin/`, which is Isabella's folder. OK to add it there, or should the credit stay only in `export/`?
10. **Where creators' games live.** For creators outside the engine repo, `export/games.bend`'s exhaustive match becomes a `GAME.bend` in their repo. The protocol does not care. When?

## Slice plan (one PR each, each passing `bun run check` and saying what was not tested)

| PR | What | Verified by |
|---|---|---|
| 0 | This design (revision 2), docs only, in PR #2; then ready and merged | review |
| 1 | `export/contract.bend`, `export/LAWS.bend` + `PROOF.bend`, `mannequin/credit.bend`, `tests/export.bend` (+ CREDITS.md agreement test) | laws prove; the numeric checks listed in `export/LAWS` pass |
| 2 | `LAYERS.bend` + laws; the fence step uses it; FOLDERS += export | `check` passes on main; a planted editor import fails |
| 3 | `PROJECT.find` + law, `export/needs.bend` + `games.bend`, game page + minimal `runGame`, `export/web.ts`, `bun run export web` + `serve` (Character, no clips) | `out/web/character/` plays under `export serve`; a canvas picture matches the editor's at the same camera; real sizes printed |
| 4 | `ui/credits.bend` written as static `credits.html`, and `index.html` from `Contract.page` | the page and credits read from `export serve`; `ui-verify` |
| — | **Request to Isabella:** `tools/clips.ts` writes one file per clip plus an index (sketch in `requests/`) | her PR, in her area |
| 5 | Per-game clips through the generated module (Animation: Jog + Jump), after the request lands | measured bundle; all 42 clips refused by `OverCode` |
| 6 | `publish/protocol.bend`, `keys.bend`, `service.bend` + laws + `tests/publish.bend` (no IO) | laws prove; numeric checks |
| 7 | `publish/server.ts`, `client.ts`, `cli.ts` against a local server in a temp root | push, idempotent re-push, agent refused on live, person promote, rollback, kill mid-upload then re-push |
| 8 | VPS: Caddy, wildcard certificate, systemd, `person caio`, first live link (Isabella's server and domain) | the live link from a phone |
| 9 | Bend-UI request command (in Bend-UI), then the editor Publish tab + dev.ts routes | `ui-verify`; publish from the editor |
| 10+ | Service mode: login, approval pages (Bend), quotas, PSL | per feature |

PRs 1–3 are the approved first slice. PR 4 is needed before any link is public, because of the CC BY credit.

## Next implementation step

Write `export/contract.bend` with its laws (`nothing_ships_when_checks_fail`, `mannequin_needs_its_credit`, `mannequin_credit_travels`, the cache laws), `mannequin/credit.bend` and `tests/export.bend`, so that `bun run check` proves them.
