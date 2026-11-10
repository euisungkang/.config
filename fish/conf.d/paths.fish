# User bin dirs (uv tools, pipx, etc.). Added every startup with --global because
# /usr/share/fish/vendor_conf.d/rocm.fish creates a global fish_user_paths that
# shadows the universal one, so a plain `fish_add_path` would not persist.
fish_add_path --global --move ~/.local/bin
