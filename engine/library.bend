# Library: the animation library's shelves.
#
# A collection is a folder of the library: the clips that came from one
# place, with its name, who made them and under which license. The credit
# belongs to the folder and goes with every clip in it, so a clip's own
# name stays plain ("Walk") and a search for "Walk" finds all of them.
#
# An entry is what the folder lists for a clip: its name, how long it
# lasts, its category (Locomotion, Idle, Actions), whether it loops, and
# its picture (a stick figure: the head as x, y, radius, then a line per
# bone as x1, y1, x2, y2, in a box of 40 by 40; none when there is no
# picture). The clip itself is made only when it is added to a character
# (library/catalog.bend's clip), because it is made for that character's
# skeleton.
#
# Limits now:
# - A folder is a flat list. Search and categories filter it in the
#   editor (editor/animation/); there are no tags.
# - A license is a short name ("CC0"); the full text stays with the
#   collection's files.

import Base

type Entry is Data:
  Entry{name: String, seconds: F32, category: String, loop: Bool, thumb: List<&2, F32>}

type Collection is Data:
  Collection{name: String, credit: String, license: String, entries: List<&2, Entry>}

def name(c: Collection) -> String:
  Collection{n, _, _, _} = c
  n

def credit(c: Collection) -> String:
  Collection{_, k, _, _} = c
  k

def license(c: Collection) -> String:
  Collection{_, _, l, _} = c
  l

def entries(c: Collection) -> List<&2, Entry>:
  Collection{_, _, _, es} = c
  es

def entry_name(e: Entry) -> String:
  Entry{n, _, _, _, _} = e
  n

def entry_seconds(e: Entry) -> F32:
  Entry{_, s, _, _, _} = e
  s

def entry_category(e: Entry) -> String:
  Entry{_, _, c, _, _} = e
  c

def entry_loops(e: Entry) -> Bool:
  Entry{_, _, _, l, _} = e
  l

def entry_thumb(e: Entry) -> List<&2, F32>:
  Entry{_, _, _, _, t} = e
  t

def with_license(none: Bool, +credit: String, +license: String) -> String:
  match none:
    case True{}:
      credit
    case False{}:
      credit ++ " · " ++ license

# The line under a folder's name: who made it and the license.
def byline(c: Collection) -> String:
  Collection{_, +k, +l, _} = c
  with_license(String.eq(l, ""), k, l)
