# The two pages of a published game, as Bend-UI trees (Web.bend), and the static text export
# writes for them:
#
#   game(title, script)       index.html: a canvas filling the window, the game's script, and a
#                             link to the credits
#   credits(title, credits)   credits.html: every third-party work the game ships, with its
#                             author, license, link and notice
#   text(tree)                a tree as HTML text, with its doctype
#
# Colors come from Bend-UI's tokens, like the editor's.
#
# Limits now:
# - Bend-UI draws trees in a live page but has no way to write one as text; text() does it here
#   (a request for Bend-UI). It writes attributes and styles; events and clocks need a live page
#   and are left out.
# - Elements that never close (meta, link, br, img) are the ones listed in Pages.void.

import Base
import ../node_modules/bend-ui/Web.bend as Web
import ../node_modules/bend-ui/TOKENS.bend as T
import ./contract.bend as Ex

# ---------- Text ----------

def Pages.pick(c: Bool, a: String, b: String) -> String:
  match c:
    case True{}:
      a
    case False{}:
      b

def Pages.char(+code: U32) -> String:
  Pages.pick(U32.is_eq(code, 38), "&amp;",
  Pages.pick(U32.is_eq(code, 60), "&lt;",
  Pages.pick(U32.is_eq(code, 62), "&gt;",
  Pages.pick(U32.is_eq(code, 34), "&quot;", SCon{Chr{code}, SNil{}}))))

def escape(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{code}, t}:
      String.append(Pages.char(code), escape(t))

def Pages.void(+tag: String) -> Bool:
  (String.eq(tag, "meta") || String.eq(tag, "link") || String.eq(tag, "br") || String.eq(tag, "img"))

def Pages.attrs(xs: List<&2, Web.Attr<Unit>>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{Web.attr{name, value}, t}:
      String.concat([" ", name, "=\"", escape(value), "\"", Pages.attrs(t)])
    case Con{_, t}:
      Pages.attrs(t)

def Pages.styles(xs: List<&2, Web.Attr<Unit>>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{Web.style{name, value}, t}:
      String.concat([name, ":", value, ";", Pages.styles(t)])
    case Con{_, t}:
      Pages.styles(t)

def Pages.style_attr(+css: String) -> String:
  Pages.pick(String.eq(css, ""), "", String.concat([" style=\"", escape(css), "\""]))

def Pages.open(+tag: String, +attrs: List<&2, Web.Attr<Unit>>) -> String:
  String.concat(["<", tag, Pages.attrs(attrs), Pages.style_attr(Pages.styles(attrs)), ">"])

def Pages.close(+tag: String) -> String:
  Pages.pick(Pages.void(tag), "", String.concat(["</", tag, ">"]))

# One def walks the tree (no mutual recursion in Bend): `whole` writes a node with its tags;
# not whole writes only its children, recursing on each child and on the node rebuilt around
# the rest of its children (CATCHES R10).
def render(t: Web.HTML<Unit>, whole: Bool) -> String:
  match t:
    case Web.text{value}:
      match whole:
        case True{}:
          escape(value)
        case False{}:
          ""
    case Web.node{+tag, +attrs, kids}:
      match kids:
        case Nil{}:
          match whole:
            case True{}:
              String.append(Pages.open(tag, attrs), Pages.close(tag))
            case False{}:
              ""
        case Con{k, rest}:
          match whole:
            case True{}:
              String.concat([Pages.open(tag, attrs), render(k, True{}),
                render(Web.node{tag, attrs, rest}, False{}), Pages.close(tag)])
            case False{}:
              String.append(render(k, True{}), render(Web.node{tag, attrs, rest}, False{}))

def text(t: Web.HTML<Unit>) -> String:
  String.append("<!doctype html>\n", String.append(render(t, True{}), "\n"))

# ---------- The pages ----------

def Pages.head(+title: String, +extra: List<&2, Web.HTML<Unit>>) -> Web.HTML<Unit>:
  Web.node{"head", [],
    List.append(&2, Web.HTML<Unit>,
      [Web.node{"meta", [Web.attr{"charset", "utf-8"}], []},
       Web.node{"meta", [Web.attr{"name", "viewport"}, Web.attr{"content", "width=device-width, initial-scale=1"}], []},
       Web.node{"title", [], [Web.text{title}]}],
      extra)}

def Pages.body_style() -> List<&2, Web.Attr<Unit>>:
  [Web.style{"margin", "0"}, Web.style{"background", T.dark_bg()}, Web.style{"color", T.dark_text()},
   Web.style{"font-family", "system-ui, sans-serif"}]

def game(+title: String, +script: String) -> Web.HTML<Unit>:
  Web.node{"html", [Web.attr{"lang", "en"}],
    [Pages.head(title, [Web.node{"script", [Web.attr{"type", "module"}, Web.attr{"src", script}], []}]),
     Web.node{"body", Pages.body_style(),
       [Web.node{"canvas", [Web.attr{"id", "game"},
          Web.style{"display", "block"}, Web.style{"width", "100vw"}, Web.style{"height", "100vh"}], []},
        Web.node{"a", [Web.attr{"href", "credits.html"},
          Web.style{"position", "fixed"}, Web.style{"right", "1em"}, Web.style{"bottom", "1em"},
          Web.style{"color", T.dark_text()}], [Web.text{"Credits"}]}]}]}

def Pages.work(c: Ex.Credit) -> Web.HTML<Unit>:
  match c:
    case Ex.Credit{title, author, license, +url, notice}:
      Web.node{"li", [],
        [Web.node{"strong", [], [Web.text{title}]},
         Web.text{String.concat([" by ", author, " (", license, ") "])},
         Web.node{"a", [Web.attr{"href", url}, Web.style{"color", T.dark_text()}], [Web.text{url}]},
         Web.text{String.append(" ", notice)}]}

def Pages.works(cs: List<&2, Ex.Credit>) -> List<&2, Web.HTML<Unit>>:
  match cs:
    case Nil{}:
      []
    case Con{c, t}:
      Pages.work(c) <> Pages.works(t)

def credits(+title: String, cs: List<&2, Ex.Credit>) -> Web.HTML<Unit>:
  Web.node{"html", [Web.attr{"lang", "en"}],
    [Pages.head(String.append(title, ": credits"), []),
     Web.node{"body", List.append(&2, Web.Attr<Unit>, Pages.body_style(), [Web.style{"padding", "2em"}]),
       [Web.node{"h1", [], [Web.text{String.append(title, ": credits")}]},
        Web.node{"ul", [], Pages.works(cs)},
        Web.node{"p", [], [Web.node{"a", [Web.attr{"href", "index.html"}, Web.style{"color", T.dark_text()}],
          [Web.text{"Back to the game"}]}]}]}]}
