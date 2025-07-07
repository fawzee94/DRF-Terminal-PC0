# .bashrc
: '
╒ ▸ 𜶋 𜵧 ═╾
╘══════╡ꔪ 🭊 ▟▛ 𜵥𜶤 𜶋 ◀:

	ᗱ ᐐ ᔖ ᕼ
	ᔵ ᘍ ᐐ ᕥ
	ᑢ ᘎ ᗑ ᗑ ᐐ ∏ ᕥ
	
	ᔖ ᕼ
	ᐳ ~/.bashrc
╼═╡ᖷ ᗐ ᔭ╞═════════════╛
'

#╒╡ᕌ ᒶ ᘎ ᗱ ᐐ ᒶ   ᕥ ᘍ ᖷ ᔖ╞┅ᐧ
#╰───────────────────────────────────────────────────────────────────────╮
	if [ -f /etc/bashrc ]; then
	    . /etc/bashrc
	fi
#	╰────────────────────────────────────────────────────────────────╯

#╒╡⊔ ᔖ ᘍ ᔵ   ᘍ ∏ ᕓ ᐞ ᔵ ᘎ ∏ ᗑ ᘍ ∏ ᒭ╞┅ᐧ
#╰───────────────────────────────────────────────────────────────────────╮
	if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
	    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
	fi
	export PATH

	#env variables
	export ICON_THEME=Tela-circle-manjaro-dark
	export XCURSOR_THEME=BreezeX-Black
	export QT_QPA_PLATFORMTHEME=qt5ct
#	╰────────────────────────────────────────────────────────────────╯

#╒╡ᐐ ᒶ ᐞ ᐐ ᔖ ᘍ ᔖ╞┅ᐧ
#╰───────────────────────────────────────────────────────────────────────╮
	alias mineshell="nix-shell -p openjdk17 wget unzip"
	alias minestart="bash ~/MINECRAFT/run.sh"
	
	alias clear="clear && fastfetch"
	alias ls="ls -a -w 1"
	
	alias figd="figlet -f /home/fwz/dotfiles/assets/fonts/figlet/DRF.flf"
	
	alias stowd="cd ~/dotfiles"
	
	alias nixconfig="sudo -E gedit /etc/nixos/configuration.nix"
	alias nixshell="nix-shell -p"
	alias nixrebuild="sudo nixos-rebuild switch"
	alias nixgens="sudo nix-env -p /nix/var/nix/profiles/system --list-generations"
#	╰────────────────────────────────────────────────────────────────╯

#╒╡ᑢ ᘎ ∏ ᖷ ᐞ ᕌ   ᗑ ᘎ ᕥ ⊔ ᒶ ᘍ ᔖ╞┅ᐧ
#╰───────────────────────────────────────────────────────────────────────╮
	if [ -d ~/.bashrc.d ]; then
	    for rc in ~/.bashrc.d/*; do
	        if [ -f "$rc" ]; then
	            . "$rc"
	        fi
	    done
	fi

	unset rc
#	╰───────────────────────────────────────────────────────────────╯

#╒╡ᖷ ᔭ ᖷ╞┅ᐧ
#╰───────────────────────────────────────────────────────────────────────╮
	#CTRL+T = fzf select
	#CTRL+R = fzf history
	#CTRL+c = fzf cd
	eval "$(fzf --bash)"

	# default options
	FZF_DEFAULT_OPTS="--layout=reverse --border=bold --border=rounded --margin=3% --color=dark --style=full"
#	╰────────────────────────────────────────────────────────────────╯

#╒╡ᔖ ᒭ ᐐ ᔵ ᒭ ⊔ ᑶ╞┅ᐧ
#╰───────────────────────────────────────────────────────────────────────╮
	fastfetch
#	╰────────────────────────────────────────────────────────────────╯
