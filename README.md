# vim-sentencer

[![Build Status](https://github.com/whonore/vim-sentencer/workflows/Tests/badge.svg?branch=master)](https://github.com/whonore/vim-sentencer/actions?query=workflow%3ATests)

One sentence per line and wrap long lines.
* Format text using `gq` with `set formatexpr=sentencer#Format()` or `:[range]Sentencer`.
* Force words to appear on the same line by "binding" them with `:SentencerBind`.

Configuration:
| Variable | Description | Default |
|---|---|---|
| `g:sentencer_punctuation` | The characters to recognize as sentence ending punctuation. | `'.!?'` |
| `g:sentencer_ignore` | A list of patterns that when followed by punctuation should not break the line. | `['e.g', 'Dr', ...]` ([full list](plugin/sentencer.vim)) |
| `g:sentencer_textwidth` |  The maximum line length before wrapping. Set to `0` to use `&textwidth` and `-1` to disable. | `0` |
| `g:sentencer_overflow` | The number of allowed characters over the max length before wrapping. Or, as a float, the percent of the max length to allow before wrapping. | `0.1` |
| `g:sentencer_filetypes` | The filetypes to automatically set `formatexpr`. Use `['*']` to enable for all filetypes. | `['markdown', 'tex', 'text']` |
