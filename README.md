# Tidal SnipGen

SuperCollider-powered snippet generator for Tidal Cycles live coding in Neovim

![Demo](https://via.placeholder.com/800x400.png?text=Demo+GIF+Placeholder)

## Rationale

This plugin streamlines live coding workflows with:

- **Automatic snippet generation** from SuperCollider-generated YAML files
- **Intelligent sound sample discovery** through FZF-lua UI
- **Parameter-aware FX/Synth composition** with dynamic snippet creation
- **Drum machine optimization** with specialized trigger patterns
- **Samples pre-listen**

Built for seamless integration with:

- [Tidal Cycles](https://tidalcycles.org/)
- [vim-tidal](https://github.com/tidalcycles/vim-tidal)
- [SuperCollider/SuperDirt](https://github.com/musikinformatik/SuperDirt)

## Installation

### Prerequisites

- Neovim ≥ 0.9
- [LuaSnip](https://github.com/L3MON4D3/LuaSnip)
- [fzf-lua](https://github.com/ibhagwan/fzf-lua)
- Tidal Cycles environment setup
- SuperCollider with SuperDirt

### Using Packer

```lua
use {
  'your-github-username/tidal-snipgen',
  requires = {
    'L3MON4D3/LuaSnip',
    'ibhagwan/fzf-lua'
  },
  config = function()
    require('tidal_snipgen').setup()
  end
}
```

### Using lazy.nvim

```lua
return {
 "gilfuser/tidal_snipgen.nvim",
 dependencies = {
  "ibhagwan/fzf-lua",
  "L3MON4D3/LuaSnip",
 },
 end
}
```

## Configuration

```lua
require('tidal_snipgen').setup({
  samples_path = nil,        -- Auto-resolved to SuperDirt samples directory
  output_path = nil,         -- Default: "~/.config/nvim/lua/assets/snipgen_tidal.lua"
  keymaps = {
    show_banks = "<leader>sb",  -- Quick access to sound banks
  },
  auto_generate = true,      -- Automatic snippet generation on YAML changes
  fzf_layout = {             -- FZF window dimensions
    width = 0.2,             -- 20% of screen width
    height = 0.9,            -- 90% of screen height 
    border = "rounded",       -- Rounded window borders
  },
})
```

### Key Features

- Path Resolution:
    **samples_path:** Automatically detects Dirt samples directory
    **output_path:** Defaults to ` ~/.config/nvim/lua/assets/snipgen_tidal.lua `

- Automation:
    Temp directory auto-creation on setup
    Immediate write for custom sample paths
    Validation of output path format

- UI Layout:
    Responsive FZF window dimensions

## 󰆦 SuperCollider Integration

Put the following lines right before the SuperDirt (SD) startup code:

```supercollider
q = q ? ();
q.added_synthDescs = q.added_synthDescs ? SynthDescLib.global.synthDescs.keys;
```

Don't use `~dirt.loadSoundFiles` or other ways to load sound files. Let the code in provided file `tidal_snipgen.scd` do the samples loading.

The samples monitor (more about that in Usage) have a GUI, where you can configure the output buses and volume. It's in the file `tidal_sg_samp_monitor.scd`. Put it also the SD startup.

Here's an example of the whole SD startup file with the **tidal_snipgen** stuff:

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

## Usage

### Snippet Patterns

#### Sound Samples

```
serbd → sergemodular-bd
se8bd → sergemodular808-bd
simsim → simmonssds400-simsd
```
