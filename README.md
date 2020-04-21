# vim-sentencer
One sentence per line and wrap long lines.

Configuration:
| Variable | Description | Default |
|---|---|---|
| `g:sentencer_punctuation` | The characters to recognize as sentence ending punctuation. | `'.!?'` |
| `g:sentencer_max_length` |  The maximum line length to wrap at. Use `-1` to disable. | `&textwidth` if not `0`, `80` otherwise |
| `g:sentencer_overflow` | The number of allowed characters over the max length before wrapping. | `g:sentencer_max_length / 10` |
| `g:sentencer_files` | The filetypes to automatically set `formatexpr`. Use `*` to enable for all filetypes. | `['markdown', 'tex', 'text']` |
