-- Add to ~/.config/hypr/bindings.lua.
--
-- SUPER+SHIFT+CTRL+A ships bound to "Agent" -> omarchy-agent, which runs plain
-- `claude`, so every window gets the same orange crab. Point it at
-- omarchy-agent-crab instead (copy it to ~/.local/bin first).
hl.unbind("SUPER + SHIFT + CTRL + A")
o.bind("SUPER + SHIFT + CTRL + A", "Agent", "omarchy-launch-tui --app-id=org.omarchy.agent omarchy-agent-crab")
