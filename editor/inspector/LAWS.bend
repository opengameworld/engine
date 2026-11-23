# The laws of editing rules in the Inspector (editor/inspector/rules.bend).
# `bend editor/inspector/PROOF.bend` must print ALL PROOFS CHECK.

import Base
import ../../engine/core/vec.bend as V
import ../../engine/script/rule.bend as R
import ./rules.bend as Ru

def one() -> List<&2, R.Rule>:
  [R.Rule{"Box", R.Trigger.Clicked{}, R.Response.Play{2}}]

# LAW: a rule added goes last, names its thing, and turns 0° when the thing is clicked.
law a_rule_added_goes_last:
  {Ru.added(one(), "Lamp") == [R.Rule{"Box", R.Trigger.Clicked{}, R.Response.Play{2}}, R.Rule{"Lamp", R.Trigger.Clicked{}, R.Response.Turn{0.0}}] : List<&2, R.Rule>}

# LAW: removing rule 0 of one leaves none.
law removing_the_only_rule_leaves_none:
  {Ru.dropped(one(), 0) == [] : List<&2, R.Rule>}

# LAW: removing a rule past the end changes nothing.
law removing_past_the_end_changes_nothing:
  {Ru.dropped(one(), 5) == one() : List<&2, R.Rule>}

# LAW: picking Started changes the trigger only.
law a_trigger_changes_alone:
  {Ru.with_when(one(), 0, 1) == [R.Rule{"Box", R.Trigger.Started{}, R.Response.Play{2}}] : List<&2, R.Rule>}

# LAW: picking the response a rule already has keeps its numbers.
law the_same_response_keeps_its_numbers:
  {Ru.with_does(one(), 0, 2) == one() : List<&2, R.Rule>}

# LAW: picking another response starts it at nothing.
law another_response_starts_at_nothing:
  {Ru.with_does(one(), 0, 0) == [R.Rule{"Box", R.Trigger.Clicked{}, R.Response.Move{V.V3{0.0, 0.0, 0.0}}}] : List<&2, R.Rule>}

# LAW: a clip is set on Play only.
law the_clip_is_plays:
  {Ru.with_clip(one(), 0, 4) == [R.Rule{"Box", R.Trigger.Clicked{}, R.Response.Play{4}}] : List<&2, R.Rule>}
