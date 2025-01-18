# Minimal makefile for Sphinx documentation
#
# You can set these variables from the command line, and also
# from the environment for the first two.
SPHINXDIR	= .sphinx
SPHINXOPTS	?= -c . -d $(SPHINXDIR)/.doctrees
SPHINXBUILD	?= sphinx-build
SOURCEDIR	= .
BUILDDIR	= _build
VENVDIR	= $(SPHINXDIR)/venv
PA11Y	= $(SPHINXDIR)/node_modules/pa11y/bin/pa11y.js --config $(SPHINXDIR)/pa11y.json
VENV	= $(VENVDIR)/bin/activate

# Detect OS for system-specific commands
UNAME := $(shell uname)

.PHONY: sp-full-help sp-woke-install sp-pa11y-install sp-install sp-run sp-html \
	sp-epub sp-serve sp-clean sp-clean-doc sp-spelling sp-linkcheck sp-woke \
	sp-pa11y sp-pdf sp-pdf-prep sp-pdf-prep-force Makefile.sp

sp-full-help: $(VENVDIR)
	@. $(VENV); $(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)
	@echo "\n\033[1;31mNOTE: This help texts shows unsupported targets!\033[0m"
	@echo "Run 'make help' to see supported targets."

$(SPHINXDIR)/requirements.txt:
	python3 $(SPHINXDIR)/build_requirements.py
ifeq ($(UNAME), Darwin)
	# macOS specific venv check
	python3 -c "import venv" || brew install python3
else
	python3 -c "import venv" || sudo apt install python3-venv
endif

$(VENVDIR): $(SPHINXDIR)/requirements.txt
	@echo "... setting up virtualenv"
	python3 -m venv $(VENVDIR)
	. $(VENV); pip install --require-virtualenv \
		--upgrade -r $(SPHINXDIR)/requirements.txt \
		--log $(VENVDIR)/pip_install.log
	@test ! -f $(VENVDIR)/pip_list.txt || \
		mv $(VENVDIR)/pip_list.txt $(VENVDIR)/pip_list.txt.bak
	@. $(VENV); pip list --local --format=freeze > $(VENVDIR)/pip_list.txt
	@touch $(VENVDIR)

sp-woke-install:
ifeq ($(UNAME), Darwin)
	@type woke >/dev/null 2>&1 || \
		{ echo "Installing \"woke\" via Homebrew... \n"; brew install woke; }
else
	@type woke >/dev/null 2>&1 || \
		{ echo "Installing \"woke\" snap... \n"; sudo snap install woke; }
endif

sp-pa11y-install:
	@type $(PA11Y) >/dev/null 2>&1 || { \
			echo "Installing \"pa11y\" from npm... \n"; \
			mkdir -p $(SPHINXDIR)/node_modules/; \
			npm install --prefix $(SPHINXDIR) pa11y; \
		}

sp-install: $(VENVDIR)
ifeq ($(UNAME), Darwin)
	@echo "Setting up macOS development environment..."
	@if [ ! -f "$(SOURCEDIR)/conf.py.orig" ]; then \
		cp "$(SOURCEDIR)/conf.py" "$(SOURCEDIR)/conf.py.orig"; \
		perl -i -pe 's/subprocess\.check_output\("distro-info --stable",/get_ubuntu_release()/g' "$(SOURCEDIR)/conf.py"; \
	fi
else
	command -v distro-info || (sudo apt-get update; sudo apt-get install --assume-yes distro-info)
endif

sp-run: sp-install
	. $(VENV); sphinx-autobuild -b dirhtml "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS)

sp-html: sp-install
	. $(VENV); $(SPHINXBUILD) -W --keep-going -b dirhtml "$(SOURCEDIR)" "$(BUILDDIR)" -w $(SPHINXDIR)/warnings.txt $(SPHINXOPTS)

sp-epub: sp-install
	. $(VENV); $(SPHINXBUILD) -b epub "$(SOURCEDIR)" "$(BUILDDIR)" -w $(SPHINXDIR)/warnings.txt $(SPHINXOPTS)

sp-serve: sp-html
	cd "$(BUILDDIR)"; python3 -m http.server 8000

sp-clean: sp-clean-doc
	@test ! -e "$(VENVDIR)" -o -d "$(VENVDIR)" -a "$(abspath $(VENVDIR))" != "$(VENVDIR)"
	rm -rf $(VENVDIR)
	rm -f $(SPHINXDIR)/requirements.txt
	rm -rf $(SPHINXDIR)/node_modules/

sp-clean-doc:
	git clean -fx "$(BUILDDIR)"
	rm -rf $(SPHINXDIR)/.doctrees

sp-spelling: sp-html
	. $(VENV); python3 -m pyspelling -c $(SPHINXDIR)/spellingcheck.yaml -j $(shell nproc) >> spellcheck.txt

sp-linkcheck: sp-install
	. $(VENV); $(SPHINXBUILD) -b linkcheck "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) >> linkcheck.txt

sp-woke: sp-woke-install
	woke *.rst **/*.rst --exit-1-on-failure \
		-c https://github.com/canonical/Inclusive-naming/raw/main/config.yml

sp-pa11y: sp-pa11y-install sp-html
	find $(BUILDDIR) -name *.html -print0 | xargs -n 1 -0 $(PA11Y)

sp-pdf-prep: sp-install
ifeq ($(UNAME), Darwin)
	@echo "Checking for MacTeX installation..."
	@type xelatex >/dev/null 2>&1 || { \
		echo "PDF generation requires MacTeX. Please install it using:"; \
		echo "brew install --cask mactex-no-gui"; \
		echo ""; \
		echo "After installation, you may need to log out and back in."; \
		false; \
	}
else
	@. $(VENV); (dpkg-query -W -f='$${Status}' latexmk 2>/dev/null | grep -c "ok installed" >/dev/null && echo "Package latexmk is installed") || (echo "PDF generation requires the installation of the following packages: latexmk fonts-freefont-otf fonts-ibm-plex texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended texlive-font-utils texlive-lang-cjk texlive-xetex plantuml xindy tex-gyre dvipng" && echo "" && echo "make pdf-prep-force will install these packages" && echo "" && echo "Please be aware these packages will be installed to your system" && false)
endif

sp-pdf-prep-force:
ifeq ($(UNAME), Darwin)
	@echo "Installing MacTeX..."
	brew install --cask mactex-no-gui
else
	@. $(VENV); apt-get update && apt-get upgrade -y
	@. $(VENV); apt-get install --no-install-recommends -y latexmk fonts-freefont-otf fonts-ibm-plex texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended texlive-font-utils texlive-lang-cjk texlive-xetex plantuml xindy tex-gyre dvipng
endif

sp-pdf: sp-pdf-prep
	@. $(VENV); sphinx-build -M latexpdf "$(SOURCEDIR)" "_build" $(SPHINXOPTS)
	@. $(VENV); find ./_build/latex -name "*.pdf" -exec mv -t ./ {} +
	@. $(VENV); rm -r _build

%: Makefile.sp
	. $(VENV); $(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)