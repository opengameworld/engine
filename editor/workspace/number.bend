# A number as the editor's fields show it: fixed(x, d) is x with exactly d decimals ("2.50").
# Every window that writes a number in a field uses it, so they all write it the same way.
#
# Limits now:
# - A number is shown with `fixed`, which rounds in F32. The browser's own toFixed rounds the exact
#   decimal, so a value that sits on a half (2.675 with two decimals) can show its last digit one off.
# - `fixed` shows at most 4 decimals.

import Base

def pow10(+d: U32) -> F32:
  match d:
    case 0:
      1.0
    case 1:
      10.0
    case 2:
      100.0
    case 3:
      1000.0
    case _:
      10000.0

# The last d digits of n, with their zeros.
def digits(d: Nat, +n: U32) -> String:
  match d:
    case 0n:
      ""
    case 1n+p:
      digits(p, (n / 10 : U32)) ++ U32.show((n % 10 : U32))

def sign_text(negative: Bool) -> String:
  match negative:
    case True{}:
      "-"
    case False{}:
      ""

def after_dot(none: Bool, +ds: String) -> String:
  match none:
    case True{}:
      ""
    case False{}:
      "." ++ ds

# x with exactly d decimals: fixed(2.5, 2) is "2.50".
def fixed(+x: F32, +d: U32) -> String:
  +scale = pow10(d)
  +unit = F32.to_u32(scale)
  +n = F32.to_u32(F32.round((F32.abs(x) * scale : F32)))
  sign_text(F32.is_lt(x, 0.0)) ++ U32.show((n / unit : U32)) ++ after_dot(U32.is_eq(d, 0), digits(U32.to_nat(d), (n % unit : U32)))
