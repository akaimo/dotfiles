run:
	ansible-playbook -i .inventory playbook.yaml --ask-become-pass

vim:
	ansible-playbook -i .inventory playbook.yaml -t vim --ask-become-pass

brew:
	brew bundle --file=../Brewfile

stow:
	# folding 防止のため ~/.config, ~/.config/uv, ~/.claude, ~/.vim を事前に実ディレクトリとして確保する
	mkdir -p $(HOME)/.config $(HOME)/.config/uv $(HOME)/.claude $(HOME)/.vim
	stow -d $(HOME)/dotfiles -t $(HOME) home

stow-dry-run:
	stow -nv -d $(HOME)/dotfiles -t $(HOME) home

ansible-links-cleanup:
	./scripts/cleanup-ansible-links.sh

ansible-links-cleanup-dry-run:
	./scripts/cleanup-ansible-links.sh --dry-run
