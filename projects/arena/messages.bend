# The Arena's messages: what its scripts send each other (engine/script/message.bend). Each kind is
# one line, Name{field: Type, ...}, with fields of the kinds the engine keeps (F32, U32, Bool,
# String, V.V3, Id.Id). The registry writes messages_generated.bend from this file: Mail.send,
# Mail.broadcast and Mail.received, typed with these.

import Base

type Message is Data:
  Ping{}
  Hit{power: F32}
