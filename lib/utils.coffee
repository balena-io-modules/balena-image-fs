Promise = require('bluebird')
assert = require('assert')
util = require('util')
chalk = require('chalk')

exports.expect = (input, output) ->
	assert.deepEqual(input, output, chalk.red("Expected #{util.inspect(input)} to equal #{util.inspect(output)}"))

exports.extract = (stream) ->
	new Promise (resolve, reject) ->
		chunks = []
		stream.on('error', reject)
		stream.on 'data', (chunk) ->
			chunks.push(chunk)
		stream.on 'end', ->
			resolve(chunks.join(''))

exports.waitStream = (stream) ->
	new Promise (resolve, reject) ->
		stream.on('error', reject)
		stream.on('close', resolve)
