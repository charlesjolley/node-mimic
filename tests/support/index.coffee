path = require 'path'

# Make some common items global to simplify testing
global.ROOT_DIR = path.resolve __dirname, '..', '..'
global.should  = require('chai').should()
global.expect  = require('chai').expect
global.sinon   = require 'sinon'
global.mimic   = require ROOT_DIR

# Import other support files
require './fiber_mocha'

