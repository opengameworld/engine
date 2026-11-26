# A release of the engine: one folder, built from one commit, that is itself a Bend library
# (BEND_LIB). This file pins what a release is made with, names its files and writes their
# texts. tools/release/build.ts does the work (git, bun, hashing, the archive) and decides
# nothing; docs/architecture/release/README.md shows the layout.
#
#   tag_version(tag)       "v0.4.2" -> Some{"0.4.2"}; any other shape -> None
#   version_ok(v)          three numbers, no leading zeros, nothing after them
#   package(v)             the Bend package name: opengame-engine@0.4.2.0
#   package_hash(sum)      BendHub's name for a package: 0x + the first 32 hex of the sum
#   manifest_line          one line of a manifest: "<sha256> <path>\n" (BendHub's format)
#   sums(...)              SHA256SUMS, in `shasum -a 256` format
#   release_json(...)      RELEASE.json
#
# Limits now:
# - Only tags vA.B.C. Bend packages take four numbers; the fourth is always 0, so a release
#   cannot be re-published under the same tag with a fix (cut a new patch version instead).
# - Unsigned: SHA256SUMS proves an archive matches the build, not who built it. Publication
#   (signing, a GitHub Release) is not done here.
# - Bun is pinned, not shipped: a machine with another Bun version cannot build a release.
# - Releases carry no HLSL tools (dxc, spirv-cross): they are hidden while the generated files
#   are written, so the shader catalog does not depend on the build machine.
# - `bun run export web` refuses inside an installed release ("toolchain: Bend unknown"): it asks
#   `git describe` of ../bend, and a release's bend/ is not a git clone.
# - The package hash is taken over file bytes. BendHub reads text: the two agree for every file
#   that is valid UTF-8 with no byte order mark, so a release is not publishable on BendHub as is.
# - JSON strings are escaped for `"` and `\` only: every value here is hex, digits or a path of
#   the repository.

import Base

# ---------- Pins ----------

def format() -> U32: 1

def bun_version() -> String: "1.4.5"

# The engine's Bend: 2.0.40 plus the loader's tree shaking (docs/not-in-bend.txt).
def bend_version() -> String: "2.0.40"

def bend_commit() -> String: "d2862e066605189d7bd9ddf766afbf86c9cce5d7"

def bend_version_line() -> String:
  String.concat(["const VERSION = \"", bend_version(), "\";"])

def treeshake_line() -> String: "&& !k.includes(\":\");"

# What of the fork a release carries: the compiler, its guide (bend2 reads it) and its license.
def bend_paths() -> List<&2, String>: ["bend2", "guide", "LICENSE"]

def package_name() -> String: "opengame-engine"

# The generators of the gitignored Bend the engine imports, in the order `bun run check` runs
# them; they run until a pass changes nothing.
def generators() -> List<&2, String>:
  ["tools/shaders/catalog.js", "tools/project/files.js", "tools/project/registry.js"]

def max_passes() -> U32: 4

def hidden_tools() -> List<&2, String>: ["dxc", "spirv-cross"]

def hidden_env() -> List<&2, String>: ["DXC", "SPIRV_CROSS"]

# A port nothing listens on: a release must check with no package fetched from a hub.
def no_hub() -> String: "http://127.0.0.1:9"

# ---------- Versions ----------

def Rel.digits(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{c, t}:
      Bool.and(Char.is_digit(c), Rel.digits(t))

def Rel.number.at(+c: Char, t: String) -> Bool:
  match t:
    case SNil{}:
      Char.is_digit(c)
    case SCon{d, u}:
      Bool.and(Bool.not(Char.is_eq(c, Chr{48})), Rel.digits(SCon{c, SCon{d, u}}))

# One or more digits, and no leading zero unless the number is 0.
def Rel.number(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{c, t}:
      Rel.number.at(c, t)

def Rel.numbers(ps: List<&2, String>) -> Bool:
  match ps:
    case Nil{}:
      True{}
    case Con{p, t}:
      Bool.and(Rel.number(p), Rel.numbers(t))

def Rel.count(ps: List<&2, String>) -> U32:
  match ps:
    case Nil{}:
      0
    case Con{_, t}:
      (1 + Rel.count(t) : U32)

def version_ok(+v: String) -> Bool:
  Bool.and(U32.is_eq(Rel.count(String.split(v, Chr{46})), 3), Rel.numbers(String.split(v, Chr{46})))

def Rel.keep(ok: Bool, +s: String) -> Maybe<&2, String>:
  match ok:
    case True{}:
      Some{s}
    case False{}:
      None{}

def Rel.tag_at(v: Bool, +rest: String) -> Maybe<&2, String>:
  match v:
    case True{}:
      Rel.keep(version_ok(rest), rest)
    case False{}:
      None{}

def tag_version(t: String) -> Maybe<&2, String>:
  match t:
    case SNil{}:
      None{}
    case SCon{c, rest}:
      Rel.tag_at(Char.is_eq(c, Chr{118}), rest)

def tag_refused(+t: String) -> String:
  String.concat(["refused tag '", t, "': a release tag is vA.B.C (three numbers, no leading zeros, nothing after them), like v0.4.2"])

def version_refused(+v: String) -> String:
  String.concat(["refused version '", v, "': a version is A.B.C (three numbers, no leading zeros, nothing after them), like 0.4.2"])

def bun_refused(+got: String) -> String:
  String.concat(["refused: this build runs Bun ", got, ", and releases are built with Bun ", bun_version(), " (tools/release/RELEASE.bend)"])

# ---------- Names ----------

def package(+v: String) -> String:
  String.concat([package_name(), "@", v, ".0"])

def package_hash(sum: String) -> String:
  String.append("0x", String.take(sum, 32n))

def name_path(+v: String) -> String:
  String.append("names/", package(v))

def name_text(hash: String) -> String:
  String.append(hash, "\n")

# The archive's root folder, and the folder the build writes.
def folder(+v: String) -> String:
  String.concat([package_name(), "-", v])

def archive(+v: String) -> String:
  String.append(folder(v), ".tar.gz")

def manifest_file() -> String: "MANIFEST"

def release_file() -> String: "RELEASE.json"

def sums_file() -> String: "SHA256SUMS"

def shim_path() -> String: "bin/bend"

# bin/bend: the fork's compiler, run by the pinned Bun, found from the shim's own folder so the
# release can sit anywhere. A symlink to it elsewhere does not work: $0 is then the link.
def shim_text() -> String:
  "#!/bin/sh\nd=$(cd \"$(dirname \"$0\")/..\" && pwd)\nexec bun \"$d/bend/bend2/main.ts\" \"$@\"\n"

def dry_run_file() -> String: "DRY_RUN"

def dry_run_text(+commit: String) -> String:
  String.concat(["A dry run: built from commit ", commit, " without a release tag. Not a release.\n"])

# The tar mode of a file: executable (in git, or the shim) or not.
def mode(exec: Bool) -> U32:
  match exec:
    case True{}:
      493
    case False{}:
      420

# ---------- Texts ----------

def manifest_line(+sum: String, +path: String) -> String:
  String.concat([sum, " ", path, "\n"])

def sums_line(+sum: String, +file: String) -> String:
  String.concat([sum, "  ", file, "\n"])

# SHA256SUMS: RELEASE.json, then the archive (byte order of the names).
def sums(+json_sum: String, +tar_sum: String, +v: String) -> String:
  String.append(sums_line(json_sum, release_file()), sums_line(tar_sum, archive(v)))

def Json.char.at(+x: U32, esc: Bool) -> String:
  match esc:
    case True{}:
      SCon{Chr{92}, SCon{Chr{x}, SNil{}}}
    case False{}:
      SCon{Chr{x}, SNil{}}

def Json.char(c: Char) -> String:
  match c:
    case Chr{+x}:
      Json.char.at(x, U32.is_eq(x, 34) || U32.is_eq(x, 92))

def Json.body(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{c, t}:
      String.append(Json.char(c), Json.body(t))

def Json.str(s: String) -> String:
  String.concat(["\"", Json.body(s), "\""])

def Json.strs(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      []
    case Con{x, t}:
      Json.str(x) <> Json.strs(t)

# A dry run has no tag: "" in, null out.
def Json.tag(t: String) -> String:
  match t:
    case SNil{}:
      "null"
    case SCon{c, r}:
      Json.str(SCon{c, r})

def release_json(+v: String, tag: String, commit: String, epoch: U32, hash: String, manifest_sum: String, generated: List<&2, String>) -> String:
  String.concat([
    "{\"format\":", U32.show(format()),
    ",\"version\":", Json.str(v),
    ",\"tag\":", Json.tag(tag),
    ",\"commit\":", Json.str(commit),
    ",\"source_date_epoch\":", U32.show(epoch),
    ",\"package\":", Json.str(package(v)),
    ",\"hash\":", Json.str(hash),
    ",\"manifest_sha256\":", Json.str(manifest_sum),
    ",\"bend\":{\"version\":", Json.str(bend_version()), ",\"commit\":", Json.str(bend_commit()), "}",
    ",\"bun\":", Json.str(bun_version()),
    ",\"generated\":[", String.join(Json.strs(generated), ","), "]",
    ",\"shader_tools\":{\"dxc\":false,\"spirv_cross\":false}}\n"])

# Lists built from the shell, one cons at a time.
def paths_none() -> List<&2, String>: []

def path(+p: String, ps: List<&2, String>) -> List<&2, String>: p <> ps
