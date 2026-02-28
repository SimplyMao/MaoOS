#!/bin/bash

# Niri Menu

export PATH="$HOME/.local/share/omarchy/bin:$PATH"

BACK_TO_EXIT=false

back_to() {
  local parent_menu="$1"

  if [[ $BACK_TO_EXIT == "true" ]]; then
    exit 0
  elif [[ -n $parent_menu ]]; then
    "$parent_menu"
  else
    show_main_menu
  fi
}

menu() {
  local prompt="$1"
  local options="$2"
  local extra="$3"
  local preselect="$4"

  read -r -a args <<<"$extra"

  if [[ -n $preselect ]]; then
    local index
    index=$(echo -e "$options" | grep -nxF "$preselect" | cut -d: -f1)
    if [[ -n $index ]]; then
      args+=("-c" "$index")
    fi
  fi

  echo -e "$options" | walker --dmenu --width 295 --minheight 1 --maxheight 630 -p "$prompt…" -t omarchy "${args[@]}" 2>/dev/null
}

present_terminal() {
  foot bash -c "$1; echo; echo 'Press enter to close.'; read"
}

show_install_menu() {
  case $(menu "Install" "󰣇  Package\n󰣇  AUR Package\n  Development\n  Editor\n  Terminal\n󱚤  AI\n  Gaming") in
  *Package*)     foot bash -c "pacman -Slq | fzf --multi --preview 'pacman -Si {}' --preview-window=right:60% | xargs -r sudo pacman -S; echo; echo 'Press enter to close.'; read" ;;
  *AUR*)         foot bash -c "yay -Slq | fzf --multi --preview 'yay -Si {}' --preview-window=right:60% | xargs -r yay -S; echo; echo 'Press enter to close.'; read" ;;
  *Development*) show_install_development_menu ;;
  *Editor*)      show_install_editor_menu ;;
  *Terminal*)    show_install_terminal_menu ;;
  *AI*)          show_install_ai_menu ;;
  *Gaming*)      show_install_gaming_menu ;;
  *) show_main_menu ;;
  esac
}

show_install_editor_menu() {
  case $(menu "Install Editor" "  VSCode\n  Cursor\n  Zed\n  Sublime Text\n  Helix\n  Emacs\n  Neovim") in
  *VSCode*)  present_terminal "sudo pacman -S code" ;;
  *Cursor*)  present_terminal "yay -S cursor-bin" ;;
  *Zed*)     present_terminal "sudo pacman -S zed" ;;
  *Sublime*) present_terminal "yay -S sublime-text-4" ;;
  *Helix*)   present_terminal "sudo pacman -S helix" ;;
  *Emacs*)   present_terminal "sudo pacman -S emacs-wayland && systemctl --user enable --now emacs.service" ;;
  *Neovim*)  present_terminal "sudo pacman -S neovim" ;;
  *) show_install_menu ;;
  esac
}

show_install_terminal_menu() {
  case $(menu "Install Terminal" "  Foot\n  Alacritty\n  Ghostty\n  Kitty") in
  *Foot*)      present_terminal "sudo pacman -S foot" ;;
  *Alacritty*) present_terminal "sudo pacman -S alacritty" ;;
  *Ghostty*)   present_terminal "sudo pacman -S ghostty" ;;
  *Kitty*)     present_terminal "sudo pacman -S kitty" ;;
  *) show_install_menu ;;
  esac
}

show_install_ai_menu() {
  ollama_pkg=$(
    (command -v nvidia-smi &>/dev/null && echo ollama-cuda) ||
      (command -v rocminfo &>/dev/null && echo ollama-rocm) ||
      echo ollama
  )

  case $(menu "Install AI" "󱚤  Claude Code\n󱚤  Codex\n󱚤  Gemini CLI\n󱚤  Copilot CLI\n󱚤  LM Studio\n󱚤  Ollama") in
  *Claude*)  present_terminal "sudo pacman -S claude-code" ;;
  *Codex*)   present_terminal "sudo pacman -S openai-codex" ;;
  *Gemini*)  present_terminal "sudo pacman -S gemini-cli" ;;
  *Copilot*) present_terminal "yay -S github-copilot-cli" ;;
  *Studio*)  present_terminal "yay -S lmstudio" ;;
  *Ollama*)  present_terminal "sudo pacman -S $ollama_pkg" ;;
  *) show_install_menu ;;
  esac
}

show_install_gaming_menu() {
  case $(menu "Install Gaming" "  Steam\n  RetroArch\n󰍳  Minecraft\n󰖺  Xbox Controller") in
  *Steam*)     present_terminal "sudo pacman -S steam" ;;
  *RetroArch*) present_terminal "sudo pacman -S retroarch retroarch-assets libretro" ;;
  *Minecraft*) present_terminal "yay -S minecraft-launcher" ;;
  *Xbox*)      present_terminal "sudo pacman -S xpadneo-dkms" ;;
  *) show_install_menu ;;
  esac
}

show_install_development_menu() {
  case $(menu "Install Dev" "󰫏  Ruby on Rails\n  Docker\n  Node.js\n  Bun\n  Deno\n  Go\n  PHP\n  Python\n  Elixir\n  Zig\n  Rust\n  Java\n  .NET\n  OCaml\n  Clojure\n  Scala") in
  *Rails*)   present_terminal "sudo pacman -S ruby && gem install rails" ;;
  *Docker*)  present_terminal "sudo pacman -S docker docker-compose && sudo systemctl enable --now docker" ;;
  *Node*)    present_terminal "sudo pacman -S nodejs npm" ;;
  *Bun*)     present_terminal "curl -fsSL https://bun.sh/install | bash" ;;
  *Deno*)    present_terminal "sudo pacman -S deno" ;;
  *Go*)      present_terminal "sudo pacman -S go" ;;
  *PHP*)     present_terminal "sudo pacman -S php composer" ;;
  *Python*)  present_terminal "sudo pacman -S python python-pip" ;;
  *Elixir*)  present_terminal "sudo pacman -S elixir" ;;
  *Zig*)     present_terminal "sudo pacman -S zig" ;;
  *Rust*)    present_terminal "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh" ;;
  *Java*)    present_terminal "sudo pacman -S jdk-openjdk" ;;
  *NET*)     present_terminal "sudo pacman -S dotnet-sdk" ;;
  *OCaml*)   present_terminal "sudo pacman -S ocaml opam" ;;
  *Clojure*) present_terminal "sudo pacman -S clojure leiningen" ;;
  *Scala*)   present_terminal "sudo pacman -S scala sbt" ;;
  *) show_install_menu ;;
  esac
}

show_remove_menu() {
  case $(menu "Remove" "󰣇  Package\n  Development") in
  *Package*)     foot bash -c "pacman -Qq | fzf --multi --preview 'pacman -Qi {}' --preview-window=right:60% | xargs -r sudo pacman -Rns; echo; echo 'Press enter to close.'; read" ;;
  *Development*) show_remove_development_menu ;;
  *) show_main_menu ;;
  esac
}

show_remove_development_menu() {
  case $(menu "Remove Dev" "󰫏  Ruby / Rails\n  Docker\n  Node.js\n  Bun\n  Deno\n  Go\n  PHP\n  Python\n  Elixir\n  Zig\n  Rust\n  Java\n  .NET\n  OCaml\n  Clojure\n  Scala") in
  *Ruby*)    present_terminal "sudo pacman -Rns ruby" ;;
  *Docker*)  present_terminal "sudo pacman -Rns docker docker-compose && sudo systemctl disable --now docker" ;;
  *Node*)    present_terminal "sudo pacman -Rns nodejs npm" ;;
  *Bun*)     present_terminal "rm -rf ~/.bun" ;;
  *Deno*)    present_terminal "sudo pacman -Rns deno" ;;
  *Go*)      present_terminal "sudo pacman -Rns go" ;;
  *PHP*)     present_terminal "sudo pacman -Rns php composer" ;;
  *Python*)  present_terminal "sudo pacman -Rns python python-pip" ;;
  *Elixir*)  present_terminal "sudo pacman -Rns elixir" ;;
  *Zig*)     present_terminal "sudo pacman -Rns zig" ;;
  *Rust*)    present_terminal "rustup self uninstall" ;;
  *Java*)    present_terminal "sudo pacman -Rns jdk-openjdk" ;;
  *NET*)     present_terminal "sudo pacman -Rns dotnet-sdk" ;;
  *OCaml*)   present_terminal "sudo pacman -Rns ocaml opam" ;;
  *Clojure*) present_terminal "sudo pacman -Rns clojure leiningen" ;;
  *Scala*)   present_terminal "sudo pacman -Rns scala sbt" ;;
  *) show_remove_menu ;;
  esac
}

show_system_menu() {
  local options="  Lock\n󰒲  Suspend\n󰍃  Logout\n󰜉  Restart\n󰐥  Shutdown"

  case $(menu "System" "$options") in
  *Lock*)     swaylock ;;
  *Suspend*)  systemctl suspend ;;
  *Logout*)   niri msg action quit ;;
  *Restart*)  systemctl reboot ;;
  *Shutdown*) systemctl poweroff ;;
  *) back_to show_main_menu ;;
  esac
}

show_main_menu() {
  go_to_menu "$(menu "Go" "󰀻  Apps\n󰉉  Install\n󰭌  Remove\n  Update\n  About\n  System")"
}

go_to_menu() {
  case "${1,,}" in
  *apps*)    walker -p "Launch…" ;;
  *install*) show_install_menu ;;
  *remove*)  show_remove_menu ;;
  *update*)  present_terminal "sudo pacman -Syu" ;;
  *about*)   present_terminal "fastfetch" ;;
  *system*)  show_system_menu ;;
  esac
}

if [[ -n $1 ]]; then
  BACK_TO_EXIT=true
  go_to_menu "$1"
else
  show_main_menu
fi
