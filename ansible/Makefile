# sudo が必要な .pkg 系 cask(karabiner-elements, google-japanese-ime, tailscale-app)は
# brew が内部で sudo を呼ぶが sudo -A を付けないため SUDO_ASKPASS が効かない。
# sudo タイムスタンプを先に温めた上で、playbook 実行中も定期的に更新する keep-alive を
# バックグラウンドで回してからメインの ansible-playbook を起動する。
run:
	sudo -v
	@parent=$$$$; \
	( while kill -0 "$$parent" 2>/dev/null; do \
		sudo -n -v >/dev/null 2>&1 || exit; \
		sleep 60; \
	done ) & \
	keeper=$$!; \
	trap 'kill "$$keeper" 2>/dev/null' EXIT INT TERM HUP; \
	ansible-playbook -i .inventory playbook.yaml --ask-become-pass

vim:
	ansible-playbook -i .inventory playbook.yaml -t vim --ask-become-pass
