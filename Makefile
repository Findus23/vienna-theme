MAKEFLAGS  := -j 1
INS         = source/beamerthemevienna.ins
PACKAGE_SRC = $(wildcard source/*.dtx)
PACKAGE_STY = $(notdir $(PACKAGE_SRC:%.dtx=%.sty))
DEMO_SRC    = demo/demo.tex demo/demo.bib
DEMO_PDF    = demo/demo.pdf
DOC_SRC     = doc/viennatheme.dtx
DOC_PDF     = doc/viennatheme.pdf

CTAN_CONTENT = README.md $(INS) $(PACKAGE_SRC) $(DOC_SRC) $(DOC_PDF) $(DEMO_SRC) $(DEMO_PDF)

DESTDIR     ?= $(shell kpsewhich -var-value=TEXMFHOME)
INSTALL_DIR  = $(DESTDIR)/tex/latex/vienna
DOC_DIR      = $(DESTDIR)/doc/latex/vienna
CACHE_DIR   := $(shell pwd)/.latex-cache

COMPILE_TEX := latexmk -lualatex -output-directory=$(CACHE_DIR)
export TEXINPUTS:=$(shell pwd):$(shell pwd)/source:${TEXINPUTS}

DOCKER_IMAGE = latex-image
DOCKER_CONTAINER = latex-container

.PHONY: all sty doc demo clean install uninstall ctan clean-cache clean-sty ctan-version docker-run docker-build docker-rm

all: sty doc

sty: $(PACKAGE_STY)

doc: $(DOC_PDF)

demo: $(DEMO_PDF)

image: demo/demo.png


clean: clean-cache clean-sty

install: $(PACKAGE_STY) $(DOC_PDF)
	@mkdir -p $(INSTALL_DIR)
	@cp $(PACKAGE_STY) $(INSTALL_DIR)
	@mkdir -p $(DOC_DIR)
	@cp $(DOC_PDF) $(DOC_DIR)

uninstall:
	@rm -f "$(addprefix $(INSTALL_DIR)/, $(PACKAGE_STY))"
	@rmdir "$(INSTALL_DIR)"
	@rm -f "$(DOC_DIR)/$(notdir $(DOC_PDF))"
	@rmdir "$(DOC_DIR)"

clean-cache:
	@rm -rf "$(CACHE_DIR)"

clean-sty:
	@rm -f $(PACKAGE_STY)

ctan: $(CTAN_CONTENT) ctan-version
	@tar --transform "s@\(.*\)@vienna/\1@" -cf vienna-$(shell date "+%Y-%m-%d").tar.gz $(CTAN_CONTENT)

ctan-version:
	@sed -i 's@20[0-9][0-9]/[0-9]*/[0-9]*@$(shell date "+%Y/%m/%d")@' $(PACKAGE_SRC)

upload: $(DOC_PDF) $(DEMO_PDF)
	rsync -aPz $(DEMO_PDF) $(DOC_PDF) lw1.at:/var/www/static/vienna-theme/

$(CACHE_DIR):
	@mkdir -p $(CACHE_DIR)

$(PACKAGE_STY): $(PACKAGE_SRC) $(INS) | clean-cache $(CACHE_DIR)
	@cd $(dir $(INS)) && latex -output-directory=$(CACHE_DIR) $(notdir $(INS))
	@cp $(addprefix $(CACHE_DIR)/,$(PACKAGE_STY)) .

$(DOC_PDF): $(DOC_SRC) $(PACKAGE_STY) | clean-cache $(CACHE_DIR)
	@cd $(dir $(DOC_SRC)) && $(COMPILE_TEX) $(notdir $(DOC_SRC))
	@cp $(CACHE_DIR)/$(notdir $(DOC_PDF)) $(DOC_PDF)

$(DEMO_PDF): $(DEMO_SRC) $(PACKAGE_STY) | clean-cache $(CACHE_DIR)
	@cd $(dir $(DEMO_SRC)) && $(COMPILE_TEX) demo/demo.tex
	@cp $(CACHE_DIR)/$(notdir $(DEMO_PDF)) $(DEMO_PDF)


demo/demo.png: $(DEMO_PDF) | clean-cache $(CACHE_DIR)
	pdftoppm $(DEMO_PDF) $(CACHE_DIR)/slides -png -scale-to 1000
	montage -mode concatenate -tile 2x2 $(CACHE_DIR)/slides-01.png $(CACHE_DIR)/slides-03.png $(CACHE_DIR)/slides-04.png $(CACHE_DIR)/slides-29.png demo/demo.png


docker-run: docker-build
	docker run --rm=true --name $(DOCKER_CONTAINER) -i -t -v `pwd`:/data $(DOCKER_IMAGE) make

docker-build:
	docker build -t $(DOCKER_IMAGE) docker

docker-rm:
	docker rm $(DOCKER_CONTAINER)
