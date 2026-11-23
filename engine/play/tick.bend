# The tick: the game's fixed step. However long a browser frame takes, the game moves in steps
# of exactly 1/60 s, so the same keys give the same World on every machine (what a server
# checking a player, or a replay, needs).
#
# A frame adds its time to the clock (advance); the clock says how many whole steps fit (steps);
# the game runs that many ticks and the clock keeps the rest (spent). This is the accumulator of
# Fiedler's "Fix Your Timestep!". The numbers are Godot's defaults: 60 ticks per second
# (physics_ticks_per_second) and at most 8 ticks in one frame (max_physics_steps_per_frame);
# past 8 the rest of the time is dropped, so a slow frame slows the game down instead of
# making the next frame slower still. References: docs/references/input-and-tick.md.
#
# Limits now:
# - What is drawn is the last tick, not a mix of the last two (Fiedler's alpha): with 60 ticks
#   and 60 frames a second they match; on a 120 Hz screen a tick shows for two frames.

import Base

def rate() -> U32: 60
def step() -> F32: 0.016666668        # 1 / rate(), in seconds
def most() -> U32: 8                  # ticks in one frame, at most

type Clock is Data:
  Clock{left: F32, ticks: U32}        # seconds not yet run, ticks run so far

def zero() -> Clock:
  Clock{0.0, 0}

def ticks(+c: Clock) -> U32:
  Clock{_, n} = c
  n

def left(+c: Clock) -> F32:
  Clock{s, _} = c
  s

# A frame of `dt` seconds went by.
def advance(+c: Clock, +dt: F32) -> Clock:
  Clock{s, n} = c
  Clock{(s + dt : F32), n}

# How many whole ticks the clock holds now, at most most().
def steps(+c: Clock) -> U32:
  U32.min(U32.from_nat(F32.to_nat((left(c) * U32.to_f32(rate()) : F32))), most())

def Tick.pick(c: Bool, +a: F32, +b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

# After `n` ticks ran: their time is taken out. When the cap was reached, what is left past one
# tick is dropped (Godot drops it too).
def spent(+c: Clock, +n: U32) -> Clock:
  Clock{s, k} = c
  +rest = (s - U32.to_f32(n) * step() : F32)
  Clock{Tick.pick(U32.is_ge(n, most()), F32.min(rest, step()), rest), (k + n : U32)}
