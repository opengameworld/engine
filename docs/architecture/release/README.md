# Released engine versions

A release of the engine is one folder, built from one commit, that anyone can put on disk and
use without a clone of this repository or of Bend. The folder is itself a Bend library: point
`BEND_LIB` at it and a program anywhere can import the engine by name:

```bend
import opengame-engine@0.4.2.0/engine/scene/scene.bend as Scene
```

The rules, pins, names and texts are `tools/release/RELEASE.bend`, with laws in
`tools/release/LAWS.bend`. `tools/release/build.ts` does the work.

## Versions

- A release is cut from an annotated tag `vA.B.C`: three numbers, no leading zeros, no suffix.
  `v0.4`, `v01.2.3` and `v0.4.2-rc.1` are refused.
- Tag `v0.4.2` is version `0.4.2` and Bend package `opengame-engine@0.4.2.0`. Bend names a
  package with four numbers; the fourth is always 0.

## Layout

```
opengame-engine-0.4.2/                 the folder, and the archive's root
  RELEASE.json                         what was built, from what, with what
  MANIFEST                             "<sha256> <path>" for every other file, sorted by path
  names/opengame-engine@0.4.2.0        "0x<32 hex>": the package's hash
  0x<32 hex>/                          the package: the engine at the tagged commit
                                         + the generated files
                                         + node_modules/ (Bend-UI)
  bend/bend2/ bend/guide/ bend/LICENSE the engine's Bend (docs/not-in-bend.txt), at its pinned commit
  bin/bend                             runs bend/bend2/main.ts with Bun
  DRY_RUN                              only in a dry run: built without a tag, not a release
```

- **The package hash** is BendHub's: `0x` and the first 32 hex digits of the sha256 of the
  package's manifest, the sorted lines `"<sha256 of the file> <path>\n"` of every file of the
  `0x…` folder. Bend's resolver finds the package through `names/` and reads it from disk.
- **The engine's own paths keep working.** The engine reaches its Bend at `../bend`, and inside
  a release `0x…/../bend` is the release's `bend/`. Nothing in the engine changes for releases.
- **The generated files** (the shader catalog, the Project window's file list, each project's
  registry) are written in the release, by the engine's own generators, run in order until a
  pass changes nothing. RELEASE.json lists them.
- **No HLSL tools.** `dxc` and `spirv-cross` are hidden while the files are generated, so the
  shader catalog is the same on every machine. HLSL shaders appear in it with their diagnostic.

### RELEASE.json

```json
{"format":1,"version":"0.4.2","tag":"v0.4.2","commit":"<40 hex>","source_date_epoch":<commit time>,
 "package":"opengame-engine@0.4.2.0","hash":"0x<32 hex>","manifest_sha256":"<hex>",
 "bend":{"version":"2.0.40","commit":"<40 hex>"},"bun":"1.4.5",
 "generated":["editor/project/files_generated.bend", "..."],
 "shader_tools":{"dxc":false,"spirv_cross":false}}
```

In a dry run, `"tag"` is `null`.

### The archive

`opengame-engine-0.4.2.tar.gz` holds the folder. It is the same bytes on every build of the same
commit: entries sorted by path, every time the commit's time, owner and group 0 with no names,
modes 644 and 755 (`bin/bend`, and files executable in git), pax records for long paths, gzip
with no name and no time. `SHA256SUMS` lists the sha256 of `RELEASE.json` and of the archive,
in `shasum -a 256` format.

## Build

A release is built on a machine with this repository, the engine's Bend at `../bend` (holding
the pinned commit) and the pinned Bun; a build with another Bun is refused.

```sh
bun run release build v0.4.2 --out <dir>      # the tree must be clean, and HEAD at the annotated tag
```

A dry run builds any commit without a tag:

```sh
bun run release build --commit <sha> --version 0.0.1 --out <dir>
```

Both write, into an empty `<dir>`:

```
<dir>/opengame-engine-0.4.2/          the folder, ready to use
<dir>/opengame-engine-0.4.2.tar.gz
<dir>/RELEASE.json
<dir>/SHA256SUMS
```

A build takes the commit's tree (`git archive`), Bend from `../bend` at the pinned commit,
installs `node_modules/` from `bun.lock` with scripts off, writes the generated files, names the
package by its hash and then runs `bun run check` inside the package, with the release's own
`bend` first on `PATH`, `BEND_LIB` set to the folder and no hub reachable. The check must pass
and must leave every byte as it was.

## Verify

```sh
bun run release verify <dir>
```

clones this repository again (`git clone --no-local`) into a folder beside `<dir>`, builds the
same commit there, and compares the two `SHA256SUMS` byte for byte.

## Use

```sh
tar -xzf opengame-engine-0.4.2.tar.gz
export BEND_LIB="$PWD/opengame-engine-0.4.2"
export PATH="$BEND_LIB/bin:$PATH"
bend my-game.bend --check-only     # imports opengame-engine@0.4.2.0/...
```

## Limits now

- Nothing is published or signed: no GitHub Release, no signature, no pushed tag. `SHA256SUMS`
  proves an archive matches a rebuild, not who built it.
- Bun is pinned, not shipped: using a release needs Bun 1.4.5 on `PATH`.
- `bun run export web` refuses inside an installed release ("toolchain: Bend unknown"): it asks
  `git describe` of `../bend` for Bend's version, and a release's `bend/` is not a git clone.
- No HLSL tools in releases: a project's HLSL shaders carry a diagnostic, not compiled code.
- The package hash is taken over file bytes, as BendHub's formula is applied to text. They
  agree for every file that is valid UTF-8 with no byte order mark; the package holds binary
  files (textures, models), so a release is not publishable on BendHub as is.
- `bin/bend` finds the release from its own path: a symlink to it elsewhere does not work.
- `verify` rebuilds with the current checkout's release tool and Bend, not with the tool as it
  was at the released commit.
- Only tags `vA.B.C`; a fix to a release is a new patch version.
