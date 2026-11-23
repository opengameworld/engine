# The laws of engine/script (rules and how they are answered).
# `bend engine/script/PROOF.bend` must print ALL PROOFS CHECK.

import Base
import ../core/vec.bend as V
import ../core/transform.bend as Tr
import ../scene/scene.bend as S
import ./rule.bend as R
import ./respond.bend as Resp

# LAW: when nothing happened, no rule does anything.
law nothing_happened_nothing_changes:
  for s: S.Scene
  for rs: List<&2, R.Rule>
  {Resp.respond(s, rs, []) == s : S.Scene}

# LAW: a scene with no rules is not changed by anything that happens.
law no_rules_no_change:
  for s: S.Scene
  for hs: List<&2, R.Happening>
  {Resp.respond(s, [], hs) == s : S.Scene}

# LAW: a Started rule moves its thing when Play starts.
law started_moves_its_thing:
  {Resp.respond(S.Scene{[S.Thing{"a", Tr.identity(), S.Hidden{}}]}, [R.Rule{"a", R.Trigger.Started{}, R.Response.Move{V.V3{1.0, 0.0, 0.0}}}], [R.Happening.Started{}])
   == S.Scene{[S.Thing{"a", Tr.with_position(Tr.identity(), V.add(Tr.position(Tr.identity()), V.V3{1.0, 0.0, 0.0})), S.Hidden{}}]} : S.Scene}

# LAW: a click on one thing does not answer another thing's Clicked rule.
law a_click_answers_only_its_thing:
  {Resp.respond(S.Scene{[S.Thing{"a", Tr.identity(), S.Hidden{}}, S.Thing{"b", Tr.identity(), S.Hidden{}}]}, [R.Rule{"b", R.Trigger.Clicked{}, R.Response.Move{V.V3{1.0, 0.0, 0.0}}}], [R.Happening.Clicked{0}])
   == S.Scene{[S.Thing{"a", Tr.identity(), S.Hidden{}}, S.Thing{"b", Tr.identity(), S.Hidden{}}]} : S.Scene}

# LAW: a Clicked rule does not answer Play starting.
law a_click_rule_waits_for_a_click:
  {Resp.respond(S.Scene{[S.Thing{"a", Tr.identity(), S.Hidden{}}]}, [R.Rule{"a", R.Trigger.Clicked{}, R.Response.Move{V.V3{1.0, 0.0, 0.0}}}], [R.Happening.Started{}])
   == S.Scene{[S.Thing{"a", Tr.identity(), S.Hidden{}}]} : S.Scene}

# LAW: a click past the end of the scene answers nothing.
law a_click_on_no_thing_answers_nothing:
  {Resp.respond(S.Scene{[S.Thing{"a", Tr.identity(), S.Hidden{}}]}, [R.Rule{"a", R.Trigger.Clicked{}, R.Response.Move{V.V3{1.0, 0.0, 0.0}}}], [R.Happening.Clicked{3}])
   == S.Scene{[S.Thing{"a", Tr.identity(), S.Hidden{}}]} : S.Scene}
