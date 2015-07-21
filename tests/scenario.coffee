util = require('util')
Promise = require('bluebird')
fs = Promise.promisifyAll(require('fs-extra'))
assert = require('assert')
chalk = require('chalk')
path = require('path')

images =
	raspberrypi: path.join(__dirname, 'images', 'raspberrypi.img')
	edison: path.join(__dirname, 'images', 'edison-config.img')
	lorem: path.join(__dirname, 'images', 'lorem.txt')

temporals =
	raspberrypi: path.join(__dirname, 'images', 'raspberrypi.img.tmp')
	edison: path.join(__dirname, 'images', 'edison-config.img.tmp')
	lorem: path.join(__dirname, 'images', 'lorem.txt.tmp')

scenarios = []

exports.assert = (input, output) ->
	assert.deepEqual(input, output, chalk.red("Expected #{util.inspect(input)} to equal #{util.inspect(output)}"))

exports.add = (name, action, callback) ->
	scenarios.push ->
		console.log(chalk.underline("> #{name}"))

		# Use sync version since async fails on Windows with
		# EPERM issues for some reason.
		fs.copySync(images.raspberrypi, temporals.raspberrypi)
		fs.copySync(images.edison, temporals.edison)
		fs.copySync(images.lorem, temporals.lorem)

		return action.call(temporals)

exports.run = ->
	Promise.reduce scenarios, (_, scenario) ->
		return scenario()
	, null
	.finally ->
		Promise.all [
			fs.unlinkAsync(temporals.raspberrypi)
			fs.unlinkAsync(temporals.edison)
			fs.unlinkAsync(temporals.lorem)
		]
