return {
    "folke/flash.nvim",
    event = "VeryLazy",
    config = function()
      require("flash").setup({
        modes = {
          -- Desactivado: char mode remapea f/F/t/T al cargar el plugin
          -- (después de keymaps.lua) y pisaría nuestro "f" -> flash.jump().
          char = { enabled = false },
        },
      })
    end,
  }
