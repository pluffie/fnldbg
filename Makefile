PREFIX ?= /usr/local/bin
FENNEL ?= fennel
LUAROCKS = luarocks --tree _deps --lua-version 5.1
FNLFLAGS += --metadata \
						--require-as-include \
						--add-fennel-path "src/?.fnl" \
						--add-fennel-path "third-party/?.fnl" \
						--add-package-path "third-party/?.lua" \
						--add-package-path "$(shell $(LUAROCKS) path --lr-path)" \
						--add-package-cpath "$(shell $(LUAROCKS) path --lr-cpath)"

.PHONY: all
all: fnldbg metafennel

.PHONY: fnldbg
fnldbg:
	echo "#!/usr/bin/env luajit" >$@
	echo "package.cpath=" "\"$(shell $(LUAROCKS) path --lr-cpath)\"" >>$@
	$(FENNEL) $(FNLFLAGS) -c src/fnldbg/main.fnl >>$@
	chmod 755 $@

metafennel: src/metafennel/main.fnl
	echo "#!/usr/bin/env luajit" >$@
	$(FENNEL) $(FNLFLAGS) -c $< >>$@
	chmod 755 $@

.PHONY: deps
deps:
	for DEP in $$(cat deps.txt); do $(LUAROCKS) install $$DEP; done

.PHONY: install
install:
	install -D -m 755 fnldbg $(PREFIX)/bin
	install -D -m 755 metafennel $(PREFIX)/bin

.PHONY: uninstall
uninstall:
	rm $(PREFIX)/bin/fnldbg
	rm $(PREFIX)/bin/metafennel
