# The laws of a release (tools/release/RELEASE.bend). `bend tools/release/PROOF.bend` must print
# ALL PROOFS CHECK.

import Base
import ./RELEASE.bend as R

# ---------- Versions ----------

# LAW: a tag vA.B.C names version A.B.C.
law tag_names_its_version:
  {R.tag_version("v0.4.2") == Some{"0.4.2"} : Maybe<&2, String>}

law zero_is_a_number:
  {R.tag_version("v0.0.0") == Some{"0.0.0"} : Maybe<&2, String>}

law many_digits_are_a_number:
  {R.tag_version("v1.20.300") == Some{"1.20.300"} : Maybe<&2, String>}

# LAW: two numbers are not a version.
law two_numbers_are_refused:
  {R.tag_version("v0.4") == None{} : Maybe<&2, String>}

# LAW: four numbers are not a version (the package's fourth is the release's, always 0).
law four_numbers_are_refused:
  {R.tag_version("v0.4.2.0") == None{} : Maybe<&2, String>}

# LAW: a leading zero is refused, so one version has one tag.
law a_leading_zero_is_refused:
  {R.tag_version("v01.2.3") == None{} : Maybe<&2, String>}

law a_leading_zero_in_the_patch_is_refused:
  {R.tag_version("v0.4.02") == None{} : Maybe<&2, String>}

# LAW: a pre-release suffix is refused.
law a_suffix_is_refused:
  {R.tag_version("v0.4.2-rc.1") == None{} : Maybe<&2, String>}

# LAW: a tag starts with v.
law no_v_is_refused:
  {R.tag_version("0.4.2") == None{} : Maybe<&2, String>}

law an_empty_number_is_refused:
  {R.tag_version("v0..2") == None{} : Maybe<&2, String>}

law a_bare_v_is_refused:
  {R.tag_version("v") == None{} : Maybe<&2, String>}

law a_dry_run_version_is_checked_too:
  {R.version_ok("0.0.1") == True{} : Bool}

law a_dry_run_version_with_a_v_is_refused:
  {R.version_ok("v0.0.1") == False{} : Bool}

# ---------- Names ----------

# LAW: the package is opengame-engine@A.B.C.0.
law the_package_name:
  {R.package("0.4.2") == "opengame-engine@0.4.2.0" : String}

law the_name_file:
  {R.name_path("0.4.2") == "names/opengame-engine@0.4.2.0" : String}

law the_folder_and_its_archive:
  {R.archive("0.4.2") == "opengame-engine-0.4.2.tar.gz" : String}

# LAW: BendHub's package hash: 0x and the first 32 hex of the manifest's sha256.
law the_package_hash:
  {R.package_hash("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") == "0xe3b0c44298fc1c149afbf4c8996fb924" : String}

law a_name_file_holds_the_hash:
  {R.name_text("0xe3b0c44298fc1c149afbf4c8996fb924") == "0xe3b0c44298fc1c149afbf4c8996fb924\n" : String}

# ---------- Texts ----------

# LAW: a manifest line is BendHub's: the sum, one space, the path, a newline.
law a_manifest_line:
  {R.manifest_line("ab12", "engine/scene/scene.bend") == "ab12 engine/scene/scene.bend\n" : String}

# LAW: a SHA256SUMS line is `shasum -a 256`'s: the sum, two spaces, the file, a newline.
law a_sums_line:
  {R.sums_line("ab12", "RELEASE.json") == "ab12  RELEASE.json\n" : String}

law the_sums:
  {R.sums("aa", "bb", "0.4.2") == "aa  RELEASE.json\nbb  opengame-engine-0.4.2.tar.gz\n" : String}

# LAW: files are 644, executables 755.
law a_file_is_644:
  {R.mode(False{}) == 420 : U32}

law an_executable_is_755:
  {R.mode(True{}) == 493 : U32}

# LAW: a dry run's RELEASE.json has a null tag; a release's has its tag.
law a_dry_run_has_no_tag:
  {R.release_json("0.0.1", "", "c0ffee", 7, "0x12", "ff", ["a.bend"]) == "{\"format\":1,\"version\":\"0.0.1\",\"tag\":null,\"commit\":\"c0ffee\",\"source_date_epoch\":7,\"package\":\"opengame-engine@0.0.1.0\",\"hash\":\"0x12\",\"manifest_sha256\":\"ff\",\"bend\":{\"version\":\"2.0.40\",\"commit\":\"d2862e066605189d7bd9ddf766afbf86c9cce5d7\"},\"bun\":\"1.4.5\",\"generated\":[\"a.bend\"],\"shader_tools\":{\"dxc\":false,\"spirv_cross\":false}}\n" : String}

law a_release_has_its_tag:
  {R.release_json("0.4.2", "v0.4.2", "c0ffee", 7, "0x12", "ff", []) == "{\"format\":1,\"version\":\"0.4.2\",\"tag\":\"v0.4.2\",\"commit\":\"c0ffee\",\"source_date_epoch\":7,\"package\":\"opengame-engine@0.4.2.0\",\"hash\":\"0x12\",\"manifest_sha256\":\"ff\",\"bend\":{\"version\":\"2.0.40\",\"commit\":\"d2862e066605189d7bd9ddf766afbf86c9cce5d7\"},\"bun\":\"1.4.5\",\"generated\":[],\"shader_tools\":{\"dxc\":false,\"spirv_cross\":false}}\n" : String}
