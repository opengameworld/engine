# A script attached to a thing: which script (its file's name in the project's scripts/) and this
# attachment's own fields, as a Value (engine/script/value.bend). The same script on two things is
# two attachments, each with its fields: Unity's MonoBehaviour instances, Stride's ScriptComponent
# ([AllowMultipleComponents], one object each).
#
# Where a script runs (server, client or both) is the script's, not the attachment's: its runs()
# (engine/script/me.bend).

import Base
import ./value.bend as Val

type Attached is Data:
  Attached{script: String, fields: Val.Value}

def script(+a: Attached) -> String:
  Attached{s, _} = a
  s

def fields(+a: Attached) -> Val.Value:
  Attached{_, f} = a
  f

def with_fields(+a: Attached, +f: Val.Value) -> Attached:
  Attached{s, _} = a
  Attached{s, f}

# A script a project offers (the Inspector's Add Component > Script): its name, the fields a new
# attachment gets (its initial()), and where it runs, in words (engine/script/me.bend's runs_name).
type Offer is Data:
  Offer{name: String, defaults: Val.Value, runs: String}

def kind_name(+k: Offer) -> String:
  Offer{n, _, _} = k
  n

def kind_defaults(+k: Offer) -> Val.Value:
  Offer{_, d, _} = k
  d

def kind_runs(+k: Offer) -> String:
  Offer{_, _, r} = k
  r

# ---------- A thing's attachments, by their place in its list ----------

def At.pick(c: Bool, +a: Attached, +b: Attached) -> Attached:
  match c:
    case True{}:
      a
    case False{}:
      b

def At.pick_list(c: Bool, +a: List<&2, Attached>, +b: List<&2, Attached>) -> List<&2, Attached>:
  match c:
    case True{}:
      a
    case False{}:
      b

# Attachment k (the first is 0); past the end, an attachment of no script.
def nth(as: List<&2, Attached>, +k: U32) -> Attached:
  match as:
    case Nil{}:
      Attached{"", Val.Value.Rec{[], []}}
    case Con{+h, t}:
      At.pick(U32.is_eq(k, 0), h, nth(t, (k - 1 : U32)))

# The list with attachment k replaced; past the end, nothing changes.
def put(as: List<&2, Attached>, +k: U32, +x: Attached) -> List<&2, Attached>:
  match as:
    case Nil{}:
      []
    case Con{+h, +t}:
      At.pick_list(U32.is_eq(k, 0), x <> t, h <> put(t, (k - 1 : U32), x))

# The list without attachment k.
def drop(as: List<&2, Attached>, +k: U32) -> List<&2, Attached>:
  match as:
    case Nil{}:
      []
    case Con{+h, +t}:
      At.pick_list(U32.is_eq(k, 0), t, h <> drop(t, (k - 1 : U32)))

def At.pick_kind(c: Bool, +a: Offer, +b: Offer) -> Offer:
  match c:
    case True{}:
      a
    case False{}:
      b

# The kind with this name among a project's (a kind of no script when there is none).
def kind_of(ks: List<&2, Offer>, +name: String) -> Offer:
  match ks:
    case Nil{}:
      Offer{name, Val.Value.Rec{[], []}, ""}
    case Con{+h, t}:
      At.pick_kind(String.eq(kind_name(h), name), h, kind_of(t, name))
