# The laws of engine/core (math and time). `bend engine/core/PROOF.bend` must print ALL PROOFS CHECK.

import Base
import ./time.bend as Time

# ---------- Time ----------

# LAW: with reduce_motion on, time never runs by itself, whatever the frame.
law reduce_motion_freezes_time:
  for c: Time.Clock
  for dt: F32
  {Time.tick(c, dt, True{}) == c : Time.Clock}

# LAW: a paused clock stays where it is.
law paused_clock_stays:
  for s: F32
  for dt: F32
  {Time.tick(Time.Clock{s, False{}}, dt, False{}) == Time.Clock{s, False{}} : Time.Clock}

# LAW: pausing keeps the moment; playing again starts from it.
law pause_keeps_the_moment:
  for s: F32
  for p: Bool
  {Time.play(Time.pause(Time.Clock{s, p})) == Time.Clock{s, True{}} : Time.Clock}
