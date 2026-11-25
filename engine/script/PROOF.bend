# The proofs of engine/script/LAWS.bend.

import Base
import ./LAWS.bend as Laws
import ../scene/scene.bend as S
import ./rule.bend as R
import ./respond.bend as Resp

def Laws.nothing_happened_nothing_changes(s, rs):
  {==}

# With no rules, every happening leaves the scene as it is: by induction on the happenings.
def unruled(hs: List<&2, R.Happening>, s: S.Scene) -> {Resp.Resp.all(hs, [], s) == s : S.Scene}:
  match hs:
    case Nil{}:
      {==}
    case h <> t:
      unruled(t, s)

def Laws.no_rules_no_change(s, hs):
  unruled(hs, s)

def Laws.started_moves_its_thing():
  {==}

def Laws.a_click_answers_only_its_thing():
  {==}

def Laws.a_click_rule_waits_for_a_click():
  {==}

def Laws.a_click_on_no_thing_answers_nothing():
  {==}

def Laws.no_problem_no_wait():
  {==}

def Laws.a_problem_says_where():
  {==}

def Laws.a_syntax_error_says_so():
  {==}
