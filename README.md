# vim-sentencer

[![Build Status](https://github.com/whonore/vim-sentencer/workflows/Tests/badge.svg?branch=master)](https://github.com/whonore/vim-sentencer/actions?query=workflow%3ATests)

One sentence per line and wrap long lines.

Configuration:
| Variable | Description | Default |
|---|---|---|
| `g:sentencer_punctuation` | The characters to recognize as sentence ending punctuation. | `'.!?'` |
| `g:sentencer_ignore` | A list of patterns that when followed by punctuation should not break the line. | `['e.g', 'Dr', ...]` (see plugin/sentencer.vim for the full list) |
| `g:sentencer_max_length` |  The maximum line length to wrap at. Use `-1` to disable. | `&textwidth` if not `0`, `80` otherwise |
| `g:sentencer_overflow` | The number of allowed characters over the max length before wrapping. Or, as a float, the percent of the max length to allow before wrapping. | `0.1` |
| `g:sentencer_filetypes` | The filetypes to automatically set `formatexpr`. Use `[*]` to enable for all filetypes. | `['markdown', 'tex', 'text']` |
