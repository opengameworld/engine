# The laws of export (export/contract.bend). `bend export/PROOF.bend` must print ALL PROOFS CHECK.

import Base
import ./contract.bend as Ex

# ---------- Export (export/contract.bend) ----------

# LAW: nothing ships when `bun run check` failed, whatever the build measured.
law nothing_ships_when_checks_fail:
  for f: Ex.Facts
  {Ex.release(False{}, f) == Ex.Outcome.Refused{[Ex.Reason.ChecksFailed{}]} : Ex.Outcome}

# LAW: a build with the mannequin and no credits page is refused for it, whatever else ships.
law mannequin_needs_its_credit:
  for ws: List<&2, Ex.Work>
  {Ex.attribution(False{}, Ex.Work.Mannequin{} <> ws) == Ex.Reason.Uncredited{Ex.Work.Mannequin{}} <> Ex.attribution(False{}, ws) : List<&2, Ex.Reason>}

# LAW: with a credits page in the folder, no credit is owed.
law a_credits_page_owes_nothing:
  for ws: List<&2, Ex.Work>
  {Ex.attribution(True{}, ws) == [] : List<&2, Ex.Reason>}

# LAW: CC0 asks for no credit (the animation library's clips).
law cc0_asks_no_credit:
  {Ex.must_show(Ex.Work.Quaternius{}) == False{} : Bool}

# LAW: the page is fetched again on every load; code and assets, named by their hash, never change.
law the_page_revalidates:
  {Ex.cache(Ex.Role.Page{}) == Ex.Cache.Revalidate{} : Ex.Cache}

law code_is_immutable:
  {Ex.cache(Ex.Role.Code{}) == Ex.Cache.Immutable{} : Ex.Cache}

law assets_are_immutable:
  {Ex.cache(Ex.Role.Asset{}) == Ex.Cache.Immutable{} : Ex.Cache}

# LAW: the budgets are the reach rule's numbers (1.6 Mbit/s: first frame in 1.5 s, playable in 10 s).
law code_budget_is_300k:
  {Ex.code_budget() == 300000 : U32}

law asset_budget_is_2m:
  {Ex.asset_budget() == 2000000 : U32}

# LAW: the credits page is fetched again on every load too.
law the_credits_page_revalidates:
  {Ex.cache(Ex.Role.Doc{}) == Ex.Cache.Revalidate{} : Ex.Cache}
