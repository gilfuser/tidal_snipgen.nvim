# Tidal SnipGen

SuperCollider-powered snippet generator for Tidal Cycles live coding in Neovim.

![Demo](https://via.placeholder.com/800x400.png?text=Demo+GIF+Placeholder)

## Rationale

This plugin streamlines live coding workflows with:

- **Automatic snippet generation** from SuperCollider-generated YAML files
- **Intelligent sound sample discovery** through an fzf-lua UI, with a picker
  for each level (banks → samples → variations) *and* a flattened "search
  everything at once" picker
- **Sample pre-listen**, right from the picker, without it closing
- **Parameter-aware FX/Synth composition** with dynamic snippet creation
- **Drum machine detection**, so drum-machine banks are tagged/handled
  differently from regular sample folders

Built for seamless integration with:

- [Tidal Cycles](https://tidalcycles.org/)
- [tidal.nvim](https://codeberg.org/skmecs/tidal.nvim/) — the currently
  supported way to send patterns to the Tidal REPL. (Older versions of this
  plugin relied on [vim-tidal](https://github.com/tidalcycles/vim-tidal)'s
  `:TidalSend1` command; that integration has been replaced — see
  [Tidal REPL integration](#tidal-repl-integration) below.)
- [fzf-lua](https://github.com/ibhagwan/fzf-lua)
- [SuperCollider/SuperDirt](https://github.com/musikinformatik/SuperDirt)

## Installation

### Prerequisites

- Neovim ≥ 0.9
- [fzf-lua](https://github.com/ibhagwan/fzf-lua) (recent version — the
  "play without closing the UI" behavior depends on fzf-lua's
  `exec_silent` action support)
- [tidal.nvim](https://codeberg.org/skmecs/tidal.nvim/), loaded and
  configured with a running GHCI/Tidal REPL
- SuperCollider with SuperDirt

#### Optional

- [LuaSnip](https://github.com/L3MON4D3/LuaSnip) + [blink.cmp](https://cmp.saghen.dev/)
  or [nvim-cmp](https://github.com/hrsh7th/nvim-cmp), for completion of the
  generated snippets

### Using lazy.nvim

```lua
return {
  "gilfuser/tidal_snipgen.nvim",
  -- if you're working from a local clone instead of the published repo:
  -- dir = "C:/path/to/your/clone/tidal_snipgen.nvim",
  dependencies = {
    "ibhagwan/fzf-lua",
  },
  config = function()
    require("tidal_snipgen").setup({
      samples_path = nil, -- Auto-resolved to SuperDirt samples directory
      output_path = nil, -- Default: "~/.config/nvim/lua/assets/snipgen_tidal.lua"

      monitor_orbit = 6, -- orbit used to pre-listen samples

      auto_generate = true, -- Automatic snippet generation on setup

      keymaps = {
        show_banks = "<leader>sb", -- open the sound-bank picker (root level)
        show_all_samples = "<leader>sa", -- open the flattened, all-levels picker

        -- Keys used INSIDE the fzf-lua picker. You only need to override
        -- the ones you want to change; anything omitted falls back to the
        -- defaults below.
        fzf = {
          forward = "ctrl-l", -- go one level in (bank -> sample -> variation)
          backward = "ctrl-b", -- go one level back
          play = "ctrl-s", -- preview the selected item WITHOUT closing the UI
          search_all = "ctrl-a", -- jump to the flattened picker, from any level
        },
      },

      fzf_layout = {
        width = 0.2, -- 20% of screen width
        height = 0.9, -- 90% of screen height
        border = "rounded",
        row = 0.1,
        col = 1,
      },
    })
  end,
}
```

## Configuration reference

| Option                     | Default                                          | Description                                                                 |
| --------------------------- | ------------------------------------------------- | ----------------------------------------------------------------------------- |
| `samples_path`              | `nil` (auto-resolved)                              | Folder SuperDirt loads samples from.                                        |
| `output_path`                | `~/.config/nvim/lua/assets/snipgen_tidal.lua`      | Where the generated LuaSnip snippet file is written.                        |
| `monitor_orbit`              | `6`                                                | Orbit used when previewing (`ctrl-s`) a sample/variation.                   |
| `auto_generate`              | `true`                                             | Regenerate snippets automatically on setup.                                 |
| `keymaps.show_banks`         | `<leader>sb`                                       | Opens the top-level Sound Banks picker.                                     |
| `keymaps.show_all_samples`   | `<leader>sa`                                       | Opens the flattened, all-banks-at-once picker.                              |
| `keymaps.fzf.forward`        | `ctrl-l`                                           | Inside the picker: go one level deeper.                                     |
| `keymaps.fzf.backward`       | `ctrl-b`                                           | Inside the picker: go one level up.                                         |
| `keymaps.fzf.play`           | `ctrl-s`                                           | Inside the picker: preview the selection, UI stays open.                    |
| `keymaps.fzf.search_all`     | `ctrl-a`                                           | Inside the picker: jump to the flattened picker.                            |
| `fzf_layout.*`                | `width=0.2, height=0.9, border="rounded"`          | Floating window geometry for the picker.                                    |

> **Note on `ctrl-h`:** earlier versions of this plugin used `ctrl-h` for
> "go back". Many terminals send the exact same byte for `ctrl-h` and
> Backspace, which made editing the fuzzy-search query while inside a
> picker behave inconsistently. The default was moved to `ctrl-b` to avoid
> that collision; you can still remap it back if your terminal doesn't have
> this issue.

## 󰆦 SuperCollider Integration

Put the following lines right before the SuperDirt (SD) startup code:

```supercollider
q = q ? ();
q.added_synthDescs = q.added_synthDescs ? SynthDescLib.global.synthDescs.keys;
```

Don't use `~dirt.loadSoundFiles` or other ways to load sound files
yourself. Let the code in the provided `tidal_snipgen.scd` do the sample
loading — it's what populates `dirt_samps.yaml`.

The sample monitor (see [Usage](#usage)) has a GUI where you can configure
the output buses and volume. It lives in `tidal_sg_samp_monitor.scd`. Put it
in the SD startup too.

Here's an example of a whole SD startup file with the **tidal_snipgen**
stuff wired in:

```supercollider
q = q ? ();
// put it in a Routine to be sure that it will evaluate in the right order
fork {
  q.added_synthDescs = q.added_synthDescs ? SynthDescLib.global.synthDescs.keys;
  wait(0.2);
  ~dirt = SuperDirt(2, s);
  ~dirt.start(57120, 0!16); // lots of orbits!
  wait(0.2);
  // if you have your own tidal instruments and fx, load them here.
  // assuming the following files are in the same folder as the file with this code:
  "tidal_snipgen.scd".loadRelative;
  "tidal_sg_samp_monitor.scd".loadRelative;
}
```

### A note on the generated YAML

The Lua-side YAML parser this plugin ships with is a small, hand-written
one — not a full YAML implementation. `tidal_snipgen.scd` is written to
stay compatible with it, so if you ever modify the SuperCollider side,
keep these constraints in mind or the parser will either error out or
(worse) silently drop data:

- **Keys must only contain word characters, spaces, hyphens and
  underscores** — no parentheses or other punctuation (e.g. use `dur_s`,
  never `dur(s)`).
- **No duplicate keys within the same mapping.** Watch out for
  `SynthDesc` controls whose array-valued defaults (like `vowelFreqs`)
  expand into extra unnamed sub-controls — `tidal_snipgen.scd` already
  filters these out.
- **Avoid a bare `key:` with no value at the document root** followed by
  another top-level key (e.g. an effect with zero parameters, like
  SuperDirt's `silence`). The parser has no way to represent "null value"
  in that specific position and will silently nest the next key underneath
  it instead of erroring. `tidal_snipgen.scd` already skips synths/effects
  with zero parameters for this reason — if you re-enable something like
  that, make sure it still ends up nested at least one level deep, or is
  skipped.

If `dirt_fx.yaml` / `dirt_synths.yaml` / `dirt_samps.yaml` fail to parse
(`Failed to parse YAML: ...` in `:messages`), it's almost always one of the
above — check the file for a stray unusual character in a key, or a key
with no children/value.

## Usage

### Generating the YAML + snippets

1. Run your SD startup (which loads `tidal_snipgen.scd`). It scans
   `samples_path`, loads every sample into SuperDirt, and writes
   `~/.tidal_snipgen/dirt_samps.yaml`, `dirt_fx.yaml`, and
   `dirt_synths.yaml`.
2. In Neovim, `:TidalSnipgenGenerate` (or just open Neovim with
   `auto_generate = true`) reads those YAML files and (re)writes the
   LuaSnip snippet file at `output_path`.

### Browsing and pre-listening to samples

- `<leader>sb` (or `:TidalSnipgenShowBanks`) opens the **Sound Banks**
  picker.
- `<leader>sa` (or `:TidalSnipgenSearchAll`) opens a **flattened** picker
  listing every `bank + sample` pair from every bank at once — useful when
  you already know (roughly) the sample name and don't want to hunt for
  which bank it's in.
- Inside any picker:
  - `ctrl-l` — go one level in (bank → sample → variation)
  - `ctrl-b` — go one level back
  - `ctrl-n` / `ctrl-p` — move within the current level (native fzf)
  - `ctrl-s` — preview/play the highlighted sample or variation. The
    picker **stays open**, so you can audition several samples in a row.
    Playback auto-silences itself after ~16s if you don't pick something
    else first.
  - `ctrl-a` — jump straight to the flattened, all-banks picker from
    wherever you are
  - `Enter` — insert the selected bank/sample/variation name into the
    buffer, at the cursor position

### Tidal REPL integration

Playback and preview go through
[tidal.nvim](https://codeberg.org/skmecs/tidal.nvim/)'s Lua API
(`require("tidal").api.send(text)`). Make sure `tidal.nvim` is set up and
its GHCI/Tidal REPL is running *before* you try to preview a sample —
otherwise you'll get a notification (not a hard error) telling you the API
couldn't be found.

If you're still on the older `vim-tidal` integration (`:TidalSend1`), note
that it's no longer used by this plugin; switch to `tidal.nvim` or adapt
`lua/tidal_snipgen/ui.lua`'s `send_to_tidal()` function to call whatever
your Tidal plugin exposes instead.

### Snippet completion

Livecode faster with snippet completion, via LuaSnip + blink.cmp /
nvim-cmp, using the file generated at `output_path`.

### Drum machine banks vs. regular sample folders

Banks are auto-tagged as drum machines when any of their samples end in
`_bd` or `_sd` (SuperDirt's usual bass-drum/snare-drum naming convention
for drum-machine kits). Drum-machine banks show a ⚡ marker in the bank
picker, and skip the duration-qualifier label (`short`/`long`/etc.) in the
sample picker, since that's not usually meaningful for one-shot drum hits.

### Sound sample naming shorthand

```
serbd → sergemodular-bd
se8bd → sergemodular808-bd
simsim → simmonssds400-simsd
```
