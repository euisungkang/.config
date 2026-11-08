return {
  -- Kept for tmux-based systems shared via this repo. Disabled here because
  -- Hyprland handles Ctrl+hjkl pane navigation (see config/keymaps.lua and
  -- ~/.config/hypr/scripts/nvim-nav.sh). Set enabled = true on non-Hyprland
  -- / tmux machines.
  "christoomey/vim-tmux-navigator",
  enabled = false,
}
