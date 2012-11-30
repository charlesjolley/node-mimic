REPORTER   = dot
TESTS      = ./tests/unit/*_test.coffee
ACCEPTANCE_TESTS = ./tests/acceptance/*_test.coffee

MOCHA_OPTS = \
	--reporter $(REPORTER) \
	--require coffee-script \
	--require ./tests/support \
	--compilers coffee:coffee-script

MOCHA = @NODE_ENV=test ./node_modules/.bin/mocha

check: test

test: test-unit test-acceptance

test-unit:
	$(MOCHA) $(MOCHA_OPTS) $(TESTS)

test-acceptance:
	$(MOCHA) $(MOCHA_OPTS) $(ACCEPTANCE_TESTS)

test-w:
	$(MOCHA) $(MOCHA_OPTS) --watch $(TESTS) $(ACCEPTANCE_TESTS)

.PHONY: test test-unit test-acceptance #benchmark clean