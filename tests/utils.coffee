Promise = require('bluebird')
assert = require('assert')
util = require('util')
chalk = require('chalk')

exports.expect = (input, output) ->
	assert.deepEqual(input, output, chalk.red("Expected #{util.inspect(input)} to equal #{util.inspect(output)}"))

exports.extract = (stream) ->
	return new Promise (resolve, reject) ->
		result = ''
		stream.on('error', reject)
		stream.on 'data', (chunk) ->
			result += chunk
		stream.on 'end', ->
			resolve(result)

exports.waitStream = (stream) ->
	return new Promise (resolve, reject) ->
		stream.on('error', reject)
		stream.on('close', resolve)
