// What Bend cannot write for itself, written from a script's and a project's own declarations.
//
// Bend has no reflection and no call by name (engine/script/value.bend): the engine keeps an
// attached script's fields, and a message's body, as a Value, and each project's registry needs,
// for every script and every message, the two functions between its type and a Value, and the
// match that picks a script's code by its name. This file reads the declarations and writes them:
//
//   fieldsOf(text)       a script's `type State is Data: State{...}`: its fields, each a name and a
//                        kind (num, int, flag, text, vec, ref), or an error saying why not
//   messagesOf(text)     a project's messages.bend `type Message is Data:` constructors, the same way
//   stateCode(alias, k, fields)   the Bend that turns script k's State into a Value and back, and
//                        runs its start and update for the engine (engine/script/run.bend)
//   mailText(messages)   the project's messages_generated.bend: Mail.send, broadcast, received
//
// Bend checks everything written here when the project compiles, and tools/script/check.ts checks
// a script with this same code, so a field of a kind the engine cannot keep is an error in the
// editor, on the field's line.
//
// Limits now:
// - The declarations are read as text: the State and each Message constructor on one line, fields
//   as `name: Type`. A State written over several lines is not read.

// A field's kind, from the last part of its type's name (V.V3 -> V3, Id.Id -> Id).
const KINDS = { F32: "num", U32: "int", Bool: "flag", String: "text", V3: "vec", Id: "ref" };
const CTOR = { num: "Num", int: "Int", flag: "Flag", text: "Text", vec: "Vec", ref: "Ref" };
export const ALLOWED = "F32, U32, Bool, String, V.V3 or Id.Id";

// The parts of a list of fields, split at the commas outside any <...> (List<&2, F32> is one type).
function parts(body) {
  const out = [];
  let depth = 0, start = 0;
  for (let i = 0; i < body.length; i++) {
    if (body[i] === "<") depth++;
    if (body[i] === ">") depth--;
    if (body[i] === "," && depth === 0) { out.push(body.slice(start, i)); start = i + 1; }
  }
  return [...out, body.slice(start)];
}

function fieldsIn(inner, where) {
  const body = inner.trim();
  if (body === "") return { fields: [] };
  const fields = [];
  for (const part of parts(body)) {
    const m = /^\s*([a-z_][A-Za-z0-9_]*)\s*:\s*(.+?)\s*$/.exec(part);
    if (!m) return { error: `${where}: a field is written name: Type, and "${part.trim()}" is not` };
    const kind = /^[A-Za-z0-9_.]+$/.test(m[2]) ? KINDS[m[2].split(".").pop()] : undefined;
    if (!kind) return { error: `${where}: the field ${m[1]} is a ${m[2]}, and a field is ${ALLOWED}` };
    fields.push({ name: m[1], kind });
  }
  return { fields };
}

// The line (counted from 1) of an offset in a text.
const lineAt = (text, at) => text.slice(0, at).split("\n").length;

// A script's State: { fields } or { error, line }.
export function fieldsOf(text) {
  const head = /^type\s+State\s+is\s+Data\s*:\s*$/m.exec(text);
  if (!head) return { error: "a script declares its fields: type State is Data: then State{...} on the next line (State{} for none)", line: 0 };
  const after = text.slice(head.index + head[0].length);
  const m = /^\s*\n(\s+)State\{([^}]*)\}\s*$/m.exec(after);
  if (!m || after.slice(0, m.index).trim() !== "") return { error: "type State is Data: is followed by its one constructor, State{...}, on the next line", line: lineAt(text, head.index) };
  const r = fieldsIn(m[2], "State");
  return r.error ? { error: r.error, line: lineAt(text, head.index + head[0].length + m.index + 1) } : r;
}

// A project's messages: [{ name, fields }] or { error }.
export function messagesOf(text) {
  const head = /^type\s+Message\s+is\s+Data\s*:\s*$/m.exec(text);
  if (!head) return { error: "messages.bend declares type Message is Data: and its kinds of message, one per line" };
  const out = [];
  for (const line of text.slice(head.index + head[0].length).split("\n")) {
    if (line.trim() === "" || line.trim().startsWith("#")) { if (out.length && line.trim() === "") break; continue; }
    if (!/^\s/.test(line)) break;
    const m = /^\s+([A-Z][A-Za-z0-9_]*)\{([^}]*)\}\s*(#.*)?$/.exec(line);
    if (!m) return { error: `a message is written Name{field: Type, ...}, and "${line.trim()}" is not` };
    const r = fieldsIn(m[2], m[1]);
    if (r.error) return { error: r.error };
    out.push({ name: m[1], fields: r.fields });
  }
  if (!out.length) return { error: "type Message is Data: has no message under it" };
  return { messages: out };
}

const str = (s) => JSON.stringify(s);
const list = (xs) => `[${xs.join(", ")}]`;
const valueOf = (f, x) => `Val.Value.${CTOR[f.kind]}{${x}}`;
const readOf = (f, v) => `Val.${f.kind}(Val.at(${v}, ${str(f.name)}))`;

// Script k (imported as `alias`): its State to a Value and back, its defaults, where it runs, and
// one tick of it for the engine. Every def is named S<k>.<x>.
export function stateCode(alias, k, fields) {
  const p = `S${k}`, T = `${alias}.State`;
  const xs = fields.map((_, i) => `a${i}`);
  return [
    `def ${p}.from(+v: Val.Value) -> ${T}:\n  ${T}{${fields.map((f) => readOf(f, "v")).join(", ")}}`,
    `def ${p}.to(+s: ${T}) -> Val.Value:\n  ${T}{${xs.join(", ")}} = s\n  Val.Value.Rec{${list(fields.map((f) => str(f.name)))}, ${list(fields.map((f, i) => valueOf(f, xs[i])))}}`,
    `def ${p}.packed(r: Me.Me & ${T}) -> Me.Me & Val.Value:\n  (m, s) = r\n  (m, ${p}.to(s))`,
    `def ${p}.started(r: Me.Me & ${T}, +dt: F32) -> Me.Me & ${T}:\n  (m, s) = r\n  ${alias}.update(m, s, dt)`,
    `def ${p}.go(first: Bool, +me: Me.Me, +v: Val.Value, +dt: F32) -> Me.Me & Val.Value:\n  match first:\n    case True{}:\n      ${p}.packed(${p}.started(${alias}.start(me, ${p}.from(v)), dt))\n    case False{}:\n      ${p}.packed(${alias}.update(me, ${p}.from(v), dt))`,
    `def ${p}.defaults() -> Val.Value:\n  ${p}.to(${alias}.initial())`,
  ].join("\n\n") + "\n";
}

// The project's messages_generated.bend: the typed side of messages for its scripts.
export function mailText(messages) {
  const enc = messages.map((m) => {
    const xs = m.fields.map((_, i) => `a${i}`);
    return `    case Msg.${m.name}{${xs.join(", ")}}:\n      Val.Value.Rec{${list([str("$"), ...m.fields.map((f) => str(f.name))])}, ${list([`Val.Value.Text{${str(m.name)}}`, ...m.fields.map((f, i) => valueOf(f, xs[i]))])}}`;
  }).join("\n");
  const dec = messages.reduceRight((rest, m) =>
    `Mail.pick(String.eq(k, ${str(m.name)}), Some{Msg.${m.name}{${m.fields.map((f) => readOf(f, "v")).join(", ")}}}, ${rest})`, "None{}");
  return `# GENERATED by tools/project/registry.js (tools/script/shape.js) from this project's messages.bend.
# Do not edit: bun run dev, check, build and export write it again.
#
# A script sends and reads the project's messages typed (Msg.Message), and the engine carries them as
# Values (engine/script/message.bend, engine/script/value.bend):
#   send(me, to, m)          to one thing, by its id (delivered on the next tick)
#   broadcast(me, tag, m)    to every thing with a tag
#   received(me)             what the thing received since the last tick, as Got: from, message

import Base
import ../../engine/scene/id.bend as Id
import ../../engine/core/vec.bend as V
import ../../engine/script/value.bend as Val
import ../../engine/script/message.bend as M
import ../../engine/script/me.bend as Me
import ./messages.bend as Msg

type Got is Data:
  Got{from: Id.Id, message: Msg.Message}

def from(+g: Got) -> Id.Id:
  Got{f, _} = g
  f

def message(+g: Got) -> Msg.Message:
  Got{_, m} = g
  m

def encode(+m: Msg.Message) -> Val.Value:
  match m:
${enc}

def Mail.pick(c: Bool, +a: Maybe<&2, Msg.Message>, +b: Maybe<&2, Msg.Message>) -> Maybe<&2, Msg.Message>:
  match c:
    case True{}:
      a
    case False{}:
      b

def decode(+v: Val.Value) -> Maybe<&2, Msg.Message>:
  +k = Val.text(Val.at(v, "$"))
  ${dec}

def send(+me: Me.Me, +to: Id.Id, +m: Msg.Message) -> Me.Me:
  Me.post(me, M.To.One{to}, encode(m))

def broadcast(+me: Me.Me, +tag: String, +m: Msg.Message) -> Me.Me:
  Me.post(me, M.To.Tagged{tag}, encode(m))

def Mail.got(+from: Id.Id, d: Maybe<&2, Msg.Message>, rest: List<&2, Got>) -> List<&2, Got>:
  match d:
    case Some{m}:
      Got{from, m} <> rest
    case None{}:
      rest

def Mail.all(ms: List<&2, M.Mail>) -> List<&2, Got>:
  match ms:
    case Nil{}:
      []
    case Con{+h, t}:
      Mail.got(M.from(h), decode(M.body(h)), Mail.all(t))

# What the thing received since the last tick, in the order it was sent.
def received(+me: Me.Me) -> List<&2, Got>:
  Mail.all(Me.received(me))
`;
}
