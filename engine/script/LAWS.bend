# The laws of engine/script (rules and how they are answered).
# `bend engine/script/PROOF.bend` must print ALL PROOFS CHECK.

import Base
import ../core/vec.bend as V
import ../core/transform.bend as Tr
import ../scene/scene.bend as S
import ./rule.bend as R
import ./respond.bend as Resp
import ./problem.bend as Pb
import ./value.bend as Val
import ./message.bend as Msg
import ./run.bend as Run
import ../scene/id.bend as Id

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
  {Resp.respond(S.scene([S.thing("a", Tr.identity(), S.Hidden{})]), [R.Rule{"a", R.Trigger.Started{}, R.Response.Move{V.V3{1.0, 0.0, 0.0}}}], [R.Happening.Started{}])
   == S.scene([S.thing("a", Tr.with_position(Tr.identity(), V.add(Tr.position(Tr.identity()), V.V3{1.0, 0.0, 0.0})), S.Hidden{})]) : S.Scene}

# LAW: a click on one thing does not answer another thing's Clicked rule.
law a_click_answers_only_its_thing:
  {Resp.respond(S.scene([S.thing("a", Tr.identity(), S.Hidden{}), S.thing("b", Tr.identity(), S.Hidden{})]), [R.Rule{"b", R.Trigger.Clicked{}, R.Response.Move{V.V3{1.0, 0.0, 0.0}}}], [R.Happening.Clicked{0}])
   == S.scene([S.thing("a", Tr.identity(), S.Hidden{}), S.thing("b", Tr.identity(), S.Hidden{})]) : S.Scene}

# LAW: a Clicked rule does not answer Play starting.
law a_click_rule_waits_for_a_click:
  {Resp.respond(S.scene([S.thing("a", Tr.identity(), S.Hidden{})]), [R.Rule{"a", R.Trigger.Clicked{}, R.Response.Move{V.V3{1.0, 0.0, 0.0}}}], [R.Happening.Started{}])
   == S.scene([S.thing("a", Tr.identity(), S.Hidden{})]) : S.Scene}

# LAW: a click past the end of the scene answers nothing.
law a_click_on_no_thing_answers_nothing:
  {Resp.respond(S.scene([S.thing("a", Tr.identity(), S.Hidden{})]), [R.Rule{"a", R.Trigger.Clicked{}, R.Response.Move{V.V3{1.0, 0.0, 0.0}}}], [R.Happening.Clicked{3}])
   == S.scene([S.thing("a", Tr.identity(), S.Hidden{})]) : S.Scene}

# LAW: a project with no problems lets Play start.
law no_problem_no_wait:
  {Pb.any([]) == False{} : Bool}

# LAW: the Console names the script, the kind of error, its line, and what is wrong.
law a_problem_says_where:
  {Pb.said(Pb.Problem{"Mover", Pb.Fault.Type{}, 12, 3, 2, "expected S.Scene, found F32", ""}) == "Mover.bend — Type error on line 12, column 3: expected S.Scene, found F32" : String}

# LAW: a syntax error is said as one.
law a_syntax_error_says_so:
  {Pb.said(Pb.Problem{"Mover", Pb.kind_of("syntax"), 7, 1, 3, "expected a term, found 'def'", ""}) == "Mover.bend — Syntax error on line 7, column 1: expected a term, found 'def'" : String}

# ---------- Values: a script's fields (engine/script/value.bend) ----------

def speed() -> Val.Value:
  Val.Value.Rec{["speed", "pings"], [Val.Value.Num{1.0}, Val.Value.Int{0}]}

# LAW: a field set is the field read.
law a_field_set_is_read_back:
  {Val.num(Val.at(Val.with_field(speed(), "speed", Val.Value.Num{2.5}), "speed")) == 2.5 : F32}

# LAW: setting one field leaves the others.
law setting_a_field_keeps_the_others:
  {Val.int(Val.at(Val.with_field(speed(), "speed", Val.Value.Num{2.5}), "pings")) == 0 : U32}

# LAW: saved values go over the script's defaults...
law saved_values_go_over_the_defaults:
  {Val.num(Val.at(Val.merged(speed(), Val.Value.Rec{["speed"], [Val.Value.Num{3.0}]}), "speed")) == 3.0 : F32}

# LAW: ...and a field the save does not have keeps its default.
law a_field_not_saved_keeps_its_default:
  {Val.int(Val.at(Val.merged(speed(), Val.Value.Rec{["speed"], [Val.Value.Num{3.0}]}), "pings")) == 0 : U32}

# ---------- Messages (engine/script/message.bend) ----------

def ping(+to: Msg.To) -> Msg.Mail:
  Msg.Mail{Id.Id{9, 0}, to, Val.Value.Rec{[], []}}

# LAW: a message to a thing's id is for that thing...
law a_message_to_an_id_is_for_it:
  {Msg.is_for(ping(Msg.To.One{Id.Id{1, 0}}), Id.Id{1, 0}, []) == True{} : Bool}

# LAW: ...and for no other, even one at the same index of an older generation.
law a_message_to_an_id_is_for_no_other:
  {Msg.is_for(ping(Msg.To.One{Id.Id{1, 1}}), Id.Id{1, 0}, []) == False{} : Bool}

# LAW: a message to a tag is for every thing with the tag...
law a_message_to_a_tag_is_for_its_things:
  {Msg.is_for(ping(Msg.To.Tagged{"crowd"}), Id.Id{1, 0}, ["enemy", "crowd"]) == True{} : Bool}

# LAW: ...and for no thing without it.
law a_message_to_a_tag_is_for_no_other:
  {Msg.is_for(ping(Msg.To.Tagged{"crowd"}), Id.Id{1, 0}, ["enemy"]) == False{} : Bool}

# ---------- Attached scripts in a tick (engine/script/run.bend) ----------

def plain() -> S.Scene:
  S.scene([S.thing("a", Tr.identity(), S.Hidden{}), S.thing("b", Tr.identity(), S.Hidden{})])

# LAW: things with no script are what they were after the scripts' step.
law things_with_no_script_do_not_change:
  for dt: F32
  {Run.step(~Run.none, plain(), [], False{}, dt) == plain() : S.Scene}
