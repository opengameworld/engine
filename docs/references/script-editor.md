# References: the script editor, and scripts that do not compile

Read on 2026-11-25 for `editor/code/` (the script editor), `tools/script/check.ts` (Bend's checker
on a script), `engine/script/problem.bend`, `engine/play/play.bend`'s `to_mode_checked`, and the
registry's `problems()` (`tools/project/registry.js`). "FROM MEMORY" marks what no page or source
read in this session states.

## What was asked

A text editor for the project's scripts, in the editor. It checks Bend as it is typed and marks
the exact place of an error, as Visual Studio does. While a script does not compile, the editor
says so, the engine reports it in the Console, Play does not start, and the game is not built.
Only Bend for now.

## Godot (source read: github.com/godotengine/godot, master)

- `editor/script/script_text_editor.cpp`, `ScriptTextEditor::_validate_script()`: the editor asks
  the language itself (`get_editor_language()->validate(text, path, &errors, ...)`). It does not
  parse the language on its own. Each error has `start_line`, `start_column`, `end_line`,
  `end_column`, `message`, `path`. Errors from other files go to `depended_errors`.
- The error label under the code shows the first error ("Error at (line, column):" and the message)
  and `set_error_pos` jumps there. `_update_background_color()` underlines every error
  (`add_underline`) and colors its line (`set_line_background_color`).
- `editor/gui/code_editor.cpp`, `CodeTextEditor::_text_changed()` starts an `idle` timer, and the
  check runs when it times out (`text_editor/completion/idle_parse_delay`; its default value was
  not read).
- What this engine takes from it: the language's own checker, never a second parser; line and
  column from 1; the error underlined and its line colored; the message under the code.
- What it does not take: the idle timer. Here a check starts when none is running, and the answer
  asks again if the text changed (`editor/code/code.bend`). The last text typed is always
  checked, with no delay number to choose.

## Unity (FROM MEMORY; the manual page read did not say it)

- When a script does not compile, Unity keeps the last assemblies that compiled, lists the errors
  in the Console (file, line, column, message), and refuses Play mode with "All compiler errors
  have to be fixed before you can enter playmode!". A build fails too. The page read,
  https://docs.unity.com/en-us/engine/current/manual/programming-environment/code-reload-serialization/code-reload/code-reloading-editor/configurable-enter-play-mode,
  covers Enter Play Mode options only and does not say this.
- Scripts are edited in an external IDE (Visual Studio, Rider), which marks errors as you type.
- What this engine takes from it: the registry leaves a broken script out, so the rest compiles
  and the editor still opens; problems() stops Play and the build; the Console says each one.

## Unreal (FROM MEMORY)

- A Blueprint that does not compile shows its errors in the Compiler Results panel and on the node.
  C++ is compiled by the IDE or Live Coding, and a failed compile keeps the last module. PIE
  starts with a warning about a Blueprint with errors.
- Not taken: Unreal's Blueprint editor is graph-based, so its errors live on nodes, not on text.

## Game Engine Architecture, Jason Gregory (FROM MEMORY, 3rd ed., the chapters on tools and on
scripting)

- The tools are separate from the runtime and must not ship: here `editor/` and `tools/` never ship
  (LAYERS.bend), and the checker is a tool.
- Iteration time matters for scripting: a fast edit, check and run loop. Here a check takes about
  a second (in-process, through Bend's own `book_load` and `book_valid`); a save restarts the engine.

## Code editors on the web: react-simple-code-editor (source read)

- https://raw.githubusercontent.com/react-simple-code-editor/react-simple-code-editor/main/src/index.tsx:
  a `<pre aria-hidden>` with the colored code, and over it a `<textarea>` placed absolutely at
  `top: 0; left: 0; width: 100%; height: 100%`, `resize: none`, `overflow: hidden`, its letters
  clear (`-webkit-text-fill-color: transparent`). Both share font, size, line height, tab size,
  letter spacing and padding. Tab is caught to insert spaces (and Ctrl+M lets Tab leave again).
- What this engine takes: the same two layers (`editor/code/view.bend`'s styles). The browser keeps
  the caret, the selection, undo, input methods and screen readers. Measured in the browser: the
  field and the drawing have the same style and the same box (879 x 273 px), and the mark of an
  error at line 12, column 3 begins 25 px from the code's edge, where 2 characters and the padding
  put it.
- What it does not take: Tab. Web.bend does not say where the caret is, so Bend cannot insert
  there (docs/bend-ui-requests.txt).

## Bend (source read: ../bend, 2.0.40)

- `bend2/bend.ts`: an error is `Err{exp, obs, ctx, def, spn}`. `spn` is `{file: {str, ns, al}, beg,
  end}`: the text checked, its namespace (the import path, "" for the file checked), and the
  offsets of the error. `err_show` prints it, with the place underlined (PR #1063, "Errors
  underline their span"). The CLI's text does not name the file the error is in, so the checker
  is called in the process (`book_nil`, `book_load`, `book_valid`), as `bend --check-only` does in
  `bend2/main.ts`'s `book_read`.
- `book_load` replaces each import line with an empty line before parsing, so line numbers stay
  those of the file, and the column of a non-import line too.
- The root file of a check may have any name, and its imports resolve from its folder. So the
  draft sits in a hidden folder at the depth of `scripts/` (`projects/<name>/.checking-<pid>/`).
- `tools/bend-fmt-lsp` is formatting only ("intentionally exposes no diagnostics"). There is no Bend
  language server with diagnostics to use yet.
- Checked at the first error: Bend throws, so there is one problem at a time.
- `where` is a reserved word (`KEYWORDS` in bend.ts). A `match` takes only a parameter or a field,
  so each computed condition goes through its own def.

## Bend-UI (source read: node_modules/bend-ui)

- `SYNTAX.bend` cuts Bend into pieces with kinds; `syntax.js` names their classes (`syntax__kw` ...)
  and `ui.css` colors them with tokens. The editor uses the same pieces and classes.
- `web-driver.js` keeps a field's `value` while the person types (`app.typing`), so a textarea
  whose value Bend holds does not lose its caret.
- `keys.js` (`createKeys`) cancels the browser's action for a key in the keymap. Ctrl+S was not
  added: `editor/viewport/keys.bend`'s laws compare keys without their modifiers, and S walks the
  character back in Play.
