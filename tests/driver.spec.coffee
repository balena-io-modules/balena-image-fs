m = require('mochainon')
driver = require('../lib/driver')

describe 'Driver:', ->

	describe '.getDriver()', ->

		describe 'given a valid driver', ->

			beforeEach ->
				@driver = driver.getDriver({}, 0, 2048)

			it 'should have .sectorSize', ->
				m.chai.expect(@driver.sectorSize).to.equal(512)

			it 'should have .numSectors', ->
				m.chai.expect(@driver.numSectors).to.equal(4)
