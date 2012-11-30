REPORTER   = dot
TESTS      = ./tests/unit/*_test.coffee
ACCEPTANCE_TESTS = ./tests/acceptance/*_test.coffee
DOCLIB = ./lib
DOCS   = ./docs

MOCHA_OPTS = \
	--reporter $(REPORTER) \
	--require coffee-script \
	--require ./tests/support \
	--compilers coffee:coffee-script

MOCHA      = @NODE_ENV=test ./node_modules/.bin/mocha
COFFEEDOC  = ./node_modules/.bin/coffeedoc
SUPERVISOR = ./node_modules/.bin/node-supervisor

check: test

test: test-unit test-acceptance

test-unit:
	$(MOCHA) $(MOCHA_OPTS) $(TESTS)

test-acceptance:
	$(MOCHA) $(MOCHA_OPTS) $(ACCEPTANCE_TESTS)

test-w:
	$(MOCHA) $(MOCHA_OPTS) --watch $(TESTS) $(ACCEPTANCE_TESTS)

docs: 
	$(COFFEEDOC) -o $(DOCS) $(DOCLIB)
	
docs-w:
	$(SUPERVISOR) -w $(DOCLIB) -e coffee -x $(COFFEEDOC) -n exit -- -o $(DOCS) $(DOCLIB)

.PHONY: test test-unit test-acceptance docs docs-w