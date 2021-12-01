SHELL=/bin/bash

PY?=python
TAR?=0

BINDIR=bin
POFILESEXEC=$(BINDIR)/pofiles.py
FRONTENDEXEC=$(BINDIR)/frontend.py

REMOTEDATADIR=remote_data
MACSDIR=$(REMOTEDATADIR)/macs
CERTSSDIR=$(REMOTEDATADIR)/certs
DNSDIR=$(REMOTEDATADIR)/dns

ifeq ($(shell uname -m),arm64)
env = env PATH="${bin}:$$PATH /usr/bin/arch -x86_64"
else
env = env PATH="${bin}:$$PATH"
endif

# https://stackoverflow.com/questions/18136918/how-to-get-current-relative-directory-of-your-makefile
mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))
ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

ifeq ($(TAR), 0)
	POFILES_TAR_ARGS=to_tar
else
	POFILES_TAR_ARGS=from_tar
	POFILES_TAR_ARGS+=$(TAR)
endif

bin = .venv/bin
env = env PATH="${bin}:$$PATH"

.PHONY: translations translations_tar frontend update_padded_macs update_cert_fingerprints update_root_key_file

help:
	@echo 'Makefile for internet.nl'
	@echo ''
	@echo 'Usage:'
	@echo '   make translations                          combine the translation files to Django PO files'
	@echo '   make translations_tar                      create a tar from the translations'
	@echo '   make translations_tar TAR=<tar.gz file>    read the tar and update the translations'
	@echo '   make frontend                              (re)generate CSS and Javascript'
	@echo '   make update_padded_macs                    update padded MAC information'
	@echo '   make update_cert_fingerprints              update certificate fingerpint information'
	@echo '   make update_root_key_file                  update DNS root key file'

translations:
	. .venv/bin/activate && ${env} python3 $(POFILESEXEC) to_django
	@echo "Make sure to run 'compilemessages' on the server to update the actual content"

translations_tar:
	. .venv/bin/activate && ${env} python3 $(POFILESEXEC) $(POFILES_TAR_ARGS)

frontend:
	. .venv/bin/activate && ${env} python3 $(FRONTENDEXEC) js
	. .venv/bin/activate && ${env} python3 $(FRONTENDEXEC) css

update_padded_macs:
	cd $(MACSDIR); ./update-macs.sh

update_cert_fingerprints:
	cd $(CERTSSDIR); ./update-certs.sh

update_root_key_file:
	unbound-anchor -a $(DNSDIR)/root.key

venv: .venv/make_venv_complete ## Create virtual environment
.venv/make_venv_complete:
	${MAKE} clean
	python3 -m venv .venv
	. .venv/bin/activate && ${env} pip install -U pip pip-tools
	. .venv/bin/activate && ${env} pip install -Ur requirements.txt
	. .venv/bin/activate && ${env} pip install -Ur requirements-dev.txt
	# . .venv/bin/activate && ${env} pip install -Ur requirements-dev.txt
	touch .venv/make_venv_complete
	${MAKE} unbound
	${MAKE} pythonwhois

clean: ## Cleanup
clean: clean_venv

clean_venv:  # Remove venv
	@echo "Cleaning venv"
	@rm -rf .venv
	@rm -f .unbound
	@rm -f .python-whois


pip-compile:  ## synchronizes the .venv with the state of requirements.txt
	. .venv/bin/activate && ${env} python3 -m piptools compile requirements.in
	. .venv/bin/activate && ${env} python3 -m piptools compile requirements-dev.in

pip-upgrade: ## synchronizes the .venv with the state of requirements.txt
	. .venv/bin/activate && ${env} python3 -m piptools compile --upgrade requirements.in
	. .venv/bin/activate && ${env} python3 -m piptools compile --upgrade requirements-dev.in

pip-sync:  ## synchronizes the .venv with the state of requirements.txt
	. .venv/bin/activate && ${env} python3 -m piptools sync requirements.txt requirements-dev.txt

run: venv
	. .venv/bin/activate && ${env} python3 manage.py runserver 0.0.0.0:8000

run-worker: venv
	# The original worker has mapping suchas Q:w1 default etc, this translates to CELERY ROUTES in settings.py it seems.
	# Todo: currently it seems that all tasks are put on the default or celery queue as mapping is not applied.
	# Todo: Eventlet results in a database deadlock, gevent does not.
	. .venv/bin/activate && ${env} python3 -m celery -A internetnl worker -E -ldebug -Q db_worker,slow_db_worker,batch_callback,batch_main,worker_slow,celery,default,batch_slow,batch_scheduler --time-limit=300 --concurrency=20 -n generic_worker

run-worker-batch-main: venv
	. .venv/bin/activate && ${env} python3 -m celery -A internetnl worker -E -ldebug -Q batch_main --time-limit=300 --concurrency=20 -n batch_main

run-worker-batch-scheduler: venv
	. .venv/bin/activate && ${env} python3 -m celery -A internetnl worker -E -ldebug -Q batch_scheduler --time-limit=300 --concurrency=2 -n batch_scheduler

run-worker-batch-callback: venv
	. .venv/bin/activate && ${env} python3 -m celery -A internetnl worker -E -ldebug -Q batch_callback --time-limit=300 --concurrency=2 -n batch_callback

run-worker-batch-slow: venv
	. .venv/bin/activate && ${env} python3 -m celery -A internetnl worker -E -ldebug -Q batch_slow --time-limit=300 --concurrency=2 -n batch_slow

run-scheduler: venv
	. .venv/bin/activate && ${env} python3 -m celery -A internetnl beat

%:
    @:

args = `arg="$(filter-out $@,$(MAKECMDGOALS))" && echo $${arg:-${1}}`

# usage: make manage <command in manage.py>
manage: venv
	# https://stackoverflow.com/questions/6273608/how-to-pass-argument-to-makefile-from-command-line
	. .venv/bin/activate && ${env} python3 manage.py $(call args,defaultstring)


# compiling unbound for an x86_64 system:
ifeq ($(shell uname -m),arm64)
# arm64: -L/usr/local/Cellar/python@3.9/3.9.9/Frameworks/Python.framework/Versions/3.9/lib/ -L/usr/local/Cellar/python@3.9/3.9.9/Frameworks/Python.framework/Versions/3.9/lib/python3.9
PYTHON_LDFLAGS="-L -L/usr/local/Cellar/python@3.9/3.9.9/Frameworks/Python.framework/Versions/3.9/lib/python3.9"

# arm64: -I/usr/local/Cellar/python@3.9/3.9.9/Frameworks/Python.framework/Versions/3.9/include/python3.9
PYTHON_CPPFLAGS="-I/usr/local/Cellar/python@3.9/3.9.9/Frameworks/Python.framework/Versions/3.9/include/python3.9"
endif

unbound: venv .unbound
.unbound:
	# Installing python3.9 for ubuntu users: https://gist.github.com/plembo/6bc141a150cff0369574ce0b0a92f5e7
	# -I/usr/include/python3.9 -> contains Python.h and other .h files.
	# -L/usr/lib -L/usr/lib/python3.9 -lpython3.9 -> contains tons of .py files, for example chunk.py and tstats.py

	rm -rf unbound
	git clone https://github.com/internetstandards/unbound
	cd unbound && ${env} ./configure --prefix=/home/$(USER)/usr/local --enable-internetnl --with-pyunbound --with-libevent --with-libhiredis PYTHON_VERSION=3.9 PYTHON_SITE_PKG=$(ROOT_DIR)/.venv/lib/python3.9/site-packages &&  make install
	touch .unbound

unbound-x86: .unbound-x86
.unbound-x86:
	# todo: this does not work yet, see: https://github.com/NLnetLabs/unbound/issues/564
	# For m1 users:
	# arch -x86_64 /bin/bash
	# /usr/local/Homebrew/bin/brew install python@3.9
	# brew unlink python@3.9 && brew link python@3.9
	# ofc you need to also execute the file with a x86 python after compiling it... But it finds the python

	# rm -rf unbound
	# git clone https://github.com/internetstandards/unbound
	cd unbound && /usr/bin/arch -x86_64 ./configure --prefix=/home/$(USER)/usr/local --enable-internetnl --with-pyunbound --with-libevent --with-libhiredis PYTHON="/usr/local/Cellar/python@3.9/3.9.9/bin/python3.9" PYTHON_SITE_PKG=$(ROOT_DIR)/.venv/lib/python3.9/site-packages PYTHON_LDFLAGS="-L/usr/local/Cellar/python@3.9/3.9.9/Frameworks/Python.framework/Versions/3.9/lib/python3.9 -L/usr/local/Cellar/python@3.9/3.9.9/Frameworks/Python.framework/Versions/3.9/lib/python3.9/config-3.9-darwin -L/usr/local/Cellar/python@3.9/3.9.9/Frameworks/Python.framework/Versions/3.9/lib" PYTHON_CPPFLAGS="-I/usr/local/Cellar/python@3.9/3.9.9/Frameworks/Python.framework/Versions/3.9/include/python3.9" && make install
	touch .unbound-x86

pythonwhois: venv .python-whois
.python-whois:
	rm -rf python-whois
	git clone https://github.com/internetstandards/python-whois.git
	cd python-whois && git checkout internetnl
	. .venv/bin/activate && cd python-whois && ${env} python3 setup.py install
	touch .python-whois


nassl: venv .nassl
.nassl:
	rm -rf nassl_freebsd
	git clone https://github.com/internetstandards/nassl.git nassl_freebsd
	cd nassl_freebsd && git checkout internetnl
	cd nassl_freebsd && mkdir -p bin/openssl-legacy/freebsd64
	cd nassl_freebsd && mkdir -p bin/openssl-modern/freebsd64
	cd nassl_freebsd && wget http://zlib.net/zlib-1.2.11.tar.gz
	cd nassl_freebsd && tar xvfz  zlib-1.2.11.tar.gz
	cd nassl_freebsd && git clone https://github.com/PeterMosmans/openssl.git openssl-1.0.2e
	cd nassl_freebsd && cd openssl-1.0.2e; git checkout 1.0.2-chacha; cd ..
	cd nassl_freebsd && git clone https://github.com/openssl/openssl.git openssl-master
	cd nassl_freebsd && cd openssl-master; git checkout OpenSSL_1_1_1c; cd ..
	. .venv/bin/activate && cd nassl_freebsd && ${env} python3 build_from_scratch.py
	. .venv/bin/activate setup.cfgebsd && ${env} python3 setup.py install



test: .make.test	## run test suite
.make.test:
	DJANGO_SETTINGS_MODULE=internetnl.settings DJANGO_DATABASE=test ${env} coverage run --include 'internetnl/*' --omit '*migrations*' \
		-m pytest -vv -ra -k 'not integration_celery and not integration_scanners and not system' ${testargs}
	# generate coverage
	${env} coverage report
	# and pretty html
	${env} coverage html
	# ensure no model updates are commited without migrations
	${env} ${app} makemigrations --check
	@touch $@  # update timestamp


testcase: ${app}
	# run specific testcase
	# example: make testcase case=test_openstreetmaps
	DJANGO_SETTINGS_MODULE=internetnl.settings DJANGO_DATABASE=test ${env} pytest -vvv --log-cli-level=10 -k ${case}
