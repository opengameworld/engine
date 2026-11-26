# Game projects outside the engine (E6)

> **Status: proposal for review. No code yet.** Answers issue #7. It was made the way the export design was: a
> grounding pass, two structurally different designs, a comparison, and one synthesis, recorded below.

Marks: **[R]** = read or run this session, with the file and line. **[W]** = read on the web this session (sources
at the end). **[MEM]** = remembered, not read. **[U]** = unverified; a step below verifies it.

## Problem

Today a game is a folder in `projects/`, and the engine imports it. Issue #7 asks for the opposite: a creator's game
lives in its own folder (its own repository), names an engine version, and runs on that version, which is installed
once per machine. The issue already settled the direction, by comparing Unity, Unreal, Godot and Construct: the
project is its own files plus one line naming a version, and the engine is installed per version outside any
project. This document turns that into a concrete design.

Five facts make the shape non-obvious:

1. **The coupling runs the wrong way, and the engine writes into itself** [R].
   - `PROJECT.bend:37-46` imports every project and closes them in a `type Project`.
   - `LAWS.bend:12-14` proves a law over that type.
   - The editor (`editor/main.js:6`), export (`export/files.bend:23,81`), engine laws (`engine/anim/LAWS.bend:7`,
     `engine/render/LAWS.bend:8`, `engine/scene/LAWS.bend:7`) and eight tests import sample projects.
   - All three generators write into the engine: `tools/project/registry.js:108-117`, `tools/project/files.js:61`
     and `tools/shaders/catalog.js:208-229`. So does export (`export/web.ts:78-144`, `.export/`).

   An installed version that is read-only and shared by many projects cannot work like this.
2. **Bend accepts only plain names in an import path** [R].
   - Every segment must be a plain name: a letter or `_`, then letters, digits, `_` or `-`. Bend checks this after it
     resolves symlinks (`../bend/bend2/bend.ts:965,984-985,1024`).
   - So the engine cannot be imported by path from `~/.ogw/versions/0.4.0/`: `.ogw` is hidden and `0.4.0` starts
     with a digit. A project kept in `~/Documents/my.game/` could not climb to it either.
   - Tried: `../ver/0.0.1/x.bend` and `../.ogw/x.bend` both fail with "an import path of plain names". So does a
     symlink into a hidden folder.
3. **Bend already has the mechanism, and the library folder is not path-checked** [R].
   - The import forms are `import <name>@<a.b.c.d>/path.bend` and `import 0x<hash>/path.bend`. They resolve from
     `BEND_LIB` (`BEND_LIB/names/<name>@<v>` holds a hash; `BEND_LIB/0x<hash>/` holds the files;
     `bend.ts:911-1040`, `GUIDE.md:505-545`).
   - A hand-filled library needs no hub and no network. The CLI, `-o x.js`, the native build, the Bun plugin and
     `bend page.html -o dir` all accept it. Effects (`.c`/`.js`) inside a package work on both lanes.
   - Tried with `BEND_LIB` set to a folder whose path contains digit-led and dashed names: it resolves. The
     plain-name rule applies to import paths, not to where the library sits.
4. **The package boundary is strict** [R].
   - A package file imports only package files: "a hub file imports only hub files" (`bend.ts:1021-1025`).
   - Relative imports inside a package resolve inside it, and a package cannot climb out.
   - A project file may mix a relative import into the project with a package import into the engine.
   - **Two copies of the engine in one program compile, but their types do not unify** (`expected U2.Vec / observed
     U1.Vec`). So every engine file in a program must come through the same path.
5. **The check today proves the whole engine for every game** [R].
   - Laws take 17 s (`mannequin/PROOF.bend` alone 11 s). Types take 28 s for 109 files. Tests run on top of that.
   - Export runs all of it before every build (`export/web.ts:44,74`).

## Grounding

**Other engines** [W]:
- **How project code reaches engine code.** Unreal's `.Build.cs` names engine modules, and UBT compiles only the
  project's dependency chain. Unity's built-in packages (`com.unity.modules.*`, `source: builtin`) move with the
  editor version. Godot's GDExtension declares `compatibility_minimum` and `_maximum`. Defold's project names no
  version: the engine is whatever editor or `bob` runs, and engine artifacts are immutable per commit
  (`d.defold.com/archive/<sha1>/…`).
- **Templates.** Unreal ships them in `Templates/` inside each engine version (a project plus `TemplateDefs.ini`
  rename rules). Unity ships `ProjectTemplates/*.tgz` inside each editor. `cargo new` lives in the toolchain version.
  The template belongs to the version that reads it.
- **Upgrades.** Unreal offers "Open a Copy" by default, and an upgraded project no longer opens in an older engine.
  Unity's API Updater rewrites only APIs marked `UnityUpgradable`. Godot has `--validate-conversion-3to4` as a dry
  run. rustup is moving away from installing a missing toolchain implicitly.
- **Checking only the game.** Unreal's Installed Build and Unity's immutable package cache never rebuild the engine
  per project.
- **Size.** Defold's app manifest and Godot's build profiles strip engine features per game. Unreal cooks only
  what is reachable from declared roots.

**Game Engine Architecture** (Gregory, 3rd ed.) [W: the table of contents, and the runtime layer diagram of §1.6 as
reproduced in papers; the chapter text itself was not available]:
- The runtime is layered, with a game-specific layer on top that the layers below never know about (§1.6).
- Tools and the asset pipeline are versioned with the runtime that reads their output (§1.7).
- Resources are managed by the engine, not the game (§7).

A project folder that holds only the game's files, over an installed engine that never imports it, is §1.6's line
drawn in the file system. Templates and generators shipped inside each version keep §1.7's pairing. My reading of
those sections beyond their titles and the diagram is [MEM].

**Bend's direction** [R]:
- Named packages arrived in 2.0.26 (`CHANGELOG.md:645-654`). 2.0.27 protected `BEND_LIB` and `BEND_HUB` from
  project files (608-629).
- Since #1042, only `0x…/` and `name@version/` imports go to the hub (571-575). Since #1087, one file is one module
  however its path is spelled (491).
- Upstream `main` (fetched 2026-11-23) has not changed the resolver since 2.0.40.

Packages are the pattern the Bend team set for code that lives outside a project.

## Design A: the engine as a Bend package per version

- **The release step.** Each engine release fills a Bend library: `lib/names/opengame-engine@0.4.0.0` → `0x<hash>`,
  and `lib/0x<hash>/` holding the engine's Bend tree.
  - The tree is `engine/`, `editor/`, `export/*.bend`, `mannequin/`, `library/` and `platform/` Bend, with Bend-UI's
    `.bend` files at `node_modules/bend-ui/`, the same relative place as today.
  - So no engine file changes its imports.
  - The hash is computed as BendHub computes it (`main.ts:683-685`), so publishing to the hub later stays possible
    and is not required.
- **Project files** import `opengame-engine@0.4.0.0/engine/scene/scene.bend`.
  - Generated files go through the same package path: the registry, the game module, and the editor entry. So the
    project, the editor and the engine meet as one copy (fact 4).
- **The installed version folder** holds that library, the TS tools, the pinned Bend loader and `node_modules/`.
  The engine's commands run from it with `BEND_LIB` set.
- **The cost.** The version is written in every engine import of a project. It must equal `.ogw-version` (a check
  enforces it), and an upgrade rewrites those lines.

## Design B: the engine by relative path through a link

- The version folder is installed at a plain-named path (`~/ogw/engines/v0_4_0/`).
- Each project has a gitignored link `engine` → that folder, and project files import `./engine/engine/scene/…`.
- Generated files import the same way.
- **What it gains:** no packaging step, no version in import lines, and a local engine checkout works with no
  library.
- **The cost:** Bend checks the resolved path, so every folder between the project and the install must be a plain
  name (fact 2).
  - `~/Documents/2026/game`, `my.game` or `Jogos 2026` break it.
  - Moving the project or the install breaks it.
  - A link in a repository is per machine, and on Windows it needs extra rights [MEM].

## Comparison

| | A: package | B: link |
|---|---|---|
| Works for any folder a creator picks | yes: the library is not path-checked [R] | no: every folder name on the way must be plain [R] |
| One engine copy per program (fact 4) | yes, by construction | yes, if nothing reaches the engine another way |
| A project is reproducible from its repository alone | yes: the version is in its files | no: it needs a link made on each machine |
| Offline builds | yes: the library is filled when the version is installed | yes |
| Upgrading a project | rewrite the import lines (mechanical) and `.ogw-version` | change `.ogw-version` |
| A local engine checkout (`ogw link dev`) | a dev library whose package folder links to the checkout [R: works; see risks] | the link points at the checkout |
| Follows Bend's direction | yes | no: works around the path rule |

**Decision: A.** B fails for ordinary folder names, which would hit creators on day one. A's one real cost, the
version in import lines, has a precedent: Unreal's `.uproject` names its engine, and Unity's lock file names its
packages. A check that compares them keeps it honest.

## Synthesis

### A project

```
my-game/
  .ogw-version        0.4.0                         the engine version, readable without running anything
  GAME.bend           name(), main(), camera()      replaces this project's case of PROJECT.bend; seed() later
  scenes/  scenes/saved/  scripts/  shaders/        as projects/<folder>/ has today
  PROOF.bend          optional: the game's own laws
  gen/                generated, gitignored         registry, file list, shader catalog, game module, entry
```

- `gen/` is a plain name because generated Bend imports `../GAME.bend`, and a hidden folder cannot be imported
  (fact 2).
- An engine tag `v0.4.0` is package version `0.4.0.0`. The fourth number is a packaging revision, used only if a
  release must be repackaged.
- The package name is `opengame-engine`. BendHub auctions names shorter than 12 characters
  (`CHANGELOG.md:566-569`), and `ogw-engine` has 10.

### The engine's own projects

They stay in `projects/` as samples and as the team's game, with relative imports as today. `PROJECT.bend` keeps
listing them for the editor and the engine's laws. Export stops importing it: every game, sample or not, gets its own
game module (step 2).

### Steps, each shippable alone

1. **Stop writing shared files; take a project folder.** No change for the samples.
   - The three generators write per project. They take a project folder and an engine import prefix (`../../` for a
     sample; `opengame-engine@0.4.0.0/` outside).
   - `engine/scene/save.bend` (saved-file imports and path, pinned by `engine/scene/LAWS.bend:45`) and
     `editor/project/templates.bend` take the same prefix.
   - `projects/prefabs.bend` moves to editor content, and the Plane gets its own material instead of the Water
     project's.
   - `editor/defaults/ACCESSIBILITY.bend` moves to a runtime home, which retires a listed layer exception.
2. **A game module per game.**
   - `GAME.bend` for the samples too, generated from their `PROJECT.bend` case.
   - `export/files.bend` writes a `game.bend` that imports that one game, not `PROJECT.bend`.
   - Measure the saving. `export/files.bend:18-19` says "about 28 KB gzip". The export design measured 20 KB gzip
     for the Character game's runtime against 28 KB with every project, so the saving may be about 8 KB [U].
3. **Commands that take a project**: `dev`, `check` and `export web` with `--project <dir>` and `--out <dir>`.
   - `check` on a project runs the project's `PROOF.bend`, types its files and runs the layers fence. It does not
     re-prove the engine: the engine's laws were proved when the version was released.
   - `LAYERS.bend` gets a place for project files under a virtual prefix (`game/`). The shell maps paths inside the
     package back to engine-relative paths. Without this the fence is blind: `tools/layers.ts:41` drops every import
     outside the repository today.
4. **The release folder** (with E7, tags).
   - `bun run release` builds one folder per tag: the TS tools, the Bend loader, `node_modules/`, and `lib/` filled
     as in design A.
   - Install writes it under a temporary name and renames it into place, so a half-written package is never trusted
     (Bend does not re-verify a local package, and a missing file triggers a refetch [R]).
   - `templates/<id>/` ships in the same folder, for `ogw new`.
5. **The check that ties them.** On a project, `check` fails when an engine import names a version other than the
   engine running it, or when `.ogw-version` disagrees with the imports. Later, an upgrade command rewrites both on
   a clean tree (Unreal's "Open a Copy" rule) [W].

### What stays decided elsewhere

- The engine's command line, `ogw`, resolves `.ogw-version`, installs versions and sets `BEND_LIB` when it runs an
  engine command.
- A build service keeps one environment per supported version, with its library filled in advance, and reads
  `.ogw-version` before anything runs.

## Risks and checks

- **A package folder linked to a local checkout** (for working on the engine and a game at once) resolves and runs
  [R]. By the resolver's code it then gets a local namespace, so the "hub files import only hub files" rule stops
  applying to it [U]. Step 3 tests a project against a linked engine before this is relied on.
- **Bun and `bunfig.toml` from a project folder.** `bunfig.toml` is read from the working directory [U], so dev
  started in a project would serve without the Bend loader. Dev must wire the plugin itself, as `export/web.ts`
  does with `Bun.build`.
- **JS cannot import a package by name** [R: Bun tried npm, 404]. Generated `entry.js` reaches Bend only through a
  generated `.bend` file. It reaches Bend-UI's JS by the installed version's absolute `node_modules` path.
- **Two engine versions in one program** compile and then fail on types [R]. The check in step 5 turns that into
  a clear error.
- **The package is a trust root.** Nothing re-verifies local package files. Install checks the release's signed
  sums before the rename.

## Open questions for the team

1. Publish `opengame-engine` to BendHub (public and permanent), or only fill libraries from releases? This proposal
   needs no hub.
2. The shape of `GAME.bend`: `name()`, `main()`, `camera()` now and `seed()` later, as `PROJECT.bend`'s cases give
   them today?
3. `gen/` as the generated folder's name, gitignored in every project?
4. Should the editor keep opening samples through `PROJECT.bend`, or open every game, samples included, through a
   generated entry (one path instead of two)?

## Sources

- Bend: `../bend/bend2/bend.ts`, `../bend/bend2/main.ts`, `../bend/guide/GUIDE.md` and `../bend/CHANGELOG.md`, at
  fork `d2862e06` (2.0.40 plus the tree-shake patch). Experiments were run with a hand-filled `BEND_LIB` and an
  unreachable `BEND_HUB`.
- The engine at `7465b4a`: the files cited inline. Timings came from running proofs and `--check-only` on a clean
  tree.
- Unreal:
  - dev.epicgames.com/documentation/en-us/unreal-engine/managing-game-code-in-unreal-engine
  - …/unreal-engine-modules
  - …/plugins-in-unreal-engine
  - …/converting-a-project-to-an-unreal-engine-template
  - …/updating-projects-to-newer-versions-of-unreal-engine
  - …/create-an-installed-build-of-unreal-engine
  - …/cooking-content-and-creating-chunks-in-unreal-engine
- Unity:
  - docs.unity.com …/upm-manifest-prj
  - …/upm-concepts
  - …/apiupdater
  - docs.unity3d.com/Manual/webgl-distributionsize-codestripping.html
  - Hub projects window reference
- Godot:
  - docs.godotengine.org …/gdextension_file.html
  - …/upgrading_to_godot_4.html
  - …/using_engine_compilation_configuration_editor.html
  - …/exporting_for_web.html
- Defold:
  - defold.com/manuals/extensions/
  - …/bob/
  - …/app-manifest/
  - …/editor-templates
  - github.com/defold/extender (server/README.md, application.yml)
- rustup: rust-lang.github.io/rustup/overrides.html; the Rustup 1.28.1 release notes.
- Gregory, *Game Engine Architecture*, 3rd ed.: the publisher's table of contents scan; the §1.6 diagram as
  reproduced in arxiv.org/pdf/2309.06329 and arxiv.org/html/2406.05487.
