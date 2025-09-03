# vimstral
A really simple Neovim plugin to query Mistral FIM and completion models

## install
since neovim 0.11 :
```
vim.pack.add({
    {'https://github.com/elric91/vimstral'}
})
```

## enable / setup
default setup (don't forget to export your Mistral API key prior to launching neovim, i.e export MISTRAL_API_KEY=xxxxxxxxxxxxx) :
```
require 'vimstral'.setup()
```

reconfigure shortcuts :
```
require 'vimstral.setup({
  query_model = "mistral-medium-2505",
  query_api = "https://api.mistral.ai/v1/chat/completions",
  fim_model = "codestral-latest",
  fim_api =  "https://api.mistral.ai/v1/fim/completions",
  system = "Be concise and direct in your responses. Respond without unnecessary explanation.",

  signs = {
    user = '󰙊',
    assistant  = '󰄛',
  },

  keymaps = {
    user_context        = '<C-j>j', -- toggle user context on line
    fim                 = '<C-j>f', -- fill in the middle
    query               = '<C-j>r', -- ask visually selected question ('R'equest), append response
    assistant_context   = '<C-j>a', -- force the selected lines to be considered as responses
    clean_context       = '<C-j>c', -- force the context to be removed
  }
})
```

## usage
<video height="300" src="https://github.com/elric91/vimstral/blob/main/media/vimstral_exemple_1.mp4"></video>

(defaults keymaps)
\<Control-j\>r : query the model. Context will include already existing context + selected lines (or current line if no line is selected)
\<Control-j\>f : fill in the middle. If a selection is made, that includes an empty line, will try to fill the void. If no selection is made (or selection with no empty line), will continue to write from the cursor.


## inspiration & thanks
initial version on Tobyshooters AI neovim plugin (https://github.com/tobyshooters/palimpsest)
