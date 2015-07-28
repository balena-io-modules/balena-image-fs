Promise = require('bluebird')
fs = Promise.promisifyAll(require('fs'))
path = require('path')
wary = require('wary')
imagefs = require('../lib/imagefs')
utils = require('./utils')
files = require('./images/files.json')

RASPBERRYPI = path.join(__dirname, 'images', 'raspberrypi.img')
EDISON = path.join(__dirname, 'images', 'edison-config.img')
LOREM = path.join(__dirname, 'images', 'lorem.txt')

wary.it 'should read a config.json from a raspberrypi',
	raspberrypi: RASPBERRYPI
, (images) ->
	input =
		image: images.raspberrypi
		partition:
			primary: 4
			logical: 1
		path: '/config.json'

	imagefs.read(input).then(utils.extract).then (contents) ->
		utils.expect(JSON.parse(contents), files.raspberrypi['config.json'])

wary.it 'should copy files between different partitions in a raspberrypi',
	raspberrypi: RASPBERRYPI
, (images) ->
	input =
		image: images.raspberrypi
		partition:
			primary: 1
		path: '/cmdline.txt'

	output =
		image: images.raspberrypi
		partition:
			primary: 4
			logical: 1
		path: '/config.json'

	imagefs.copy(input, output).then(utils.waitStream).then ->
		imagefs.read(output).then(utils.extract).then (contents) ->
			utils.expect(contents, 'dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait \n')

wary.it 'should replace files between different partitions in a raspberrypi',
	raspberrypi: RASPBERRYPI
, (images) ->
	input =
		image: images.raspberrypi
		partition:
			primary: 1
		path: '/cmdline.txt'

	output =
		image: images.raspberrypi
		partition:
			primary: 4
			logical: 1
		path: '/cmdline.txt'

	imagefs.copy(input, output).then(utils.waitStream).then ->
		imagefs.read(output).then(utils.extract).then (contents) ->
			utils.expect(contents, 'dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait \n')

wary.it 'should copy a local file to a raspberry pi partition',
	raspberrypi: RASPBERRYPI
	lorem: LOREM
, (images) ->
	inputStream = fs.createReadStream(images.lorem)
	output =
		image: images.raspberrypi
		partition:
			primary: 4
			logical: 1
		path: '/lorem.txt'

	imagefs.write(output, inputStream).then(utils.waitStream).then ->
		imagefs.read(output).then(utils.extract).then (contents) ->
			utils.expect(contents.replace('\r', ''), 'Lorem ipsum dolor sit amet\n')

wary.it 'should copy a file from a raspberry pi partition to a local file',
	raspberrypi: RASPBERRYPI
, (images) ->
	input =
		image: images.raspberrypi
		partition:
			primary: 1
		path: '/cmdline.txt'

	output = path.join(__dirname, 'output.tmp')

	imagefs.read(input).then (inputStream) ->
		return inputStream.pipe(fs.createWriteStream(output))
	.then(utils.waitStream).then ->
		fs.createReadStream(output)
	.then(utils.extract).then (contents) ->
		utils.expect(contents, 'dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait \n')
		fs.unlinkAsync(output)

wary.it 'should replace a file in an edison config partition with a local file',
	edison: EDISON
	lorem: LOREM
, (images) ->
	inputStream = fs.createReadStream(images.lorem)
	output =
		image: images.edison
		path: '/config.json'

	imagefs.write(output, inputStream).then(utils.waitStream).then ->
		imagefs.read(output).then(utils.extract).then (contents) ->
			utils.expect(contents.replace('\r', ''), 'Lorem ipsum dolor sit amet\n')

wary.it 'should copy a file from an edison partition to a raspberry pi',
	raspberrypi: RASPBERRYPI
	edison: EDISON
, (images) ->
	input =
		image: images.edison
		path: '/config.json'

	output =
		image: images.raspberrypi
		partition:
			primary: 4
			logical: 1
		path: '/edison-config.json'

	imagefs.copy(input, output).then(utils.waitStream).then ->
		imagefs.read(output).then(utils.extract).then (contents) ->
			utils.expect(JSON.parse(contents), files.edison['config.json'])

wary.it 'should copy a file from a raspberry pi to an edison config partition',
	raspberrypi: RASPBERRYPI
	edison: EDISON
, (images) ->
	input =
		image: images.raspberrypi
		partition:
			primary: 1
		path: '/cmdline.txt'

	output =
		image: images.edison
		path: '/config.json'

	imagefs.copy(input, output).then(utils.waitStream).then ->
		imagefs.read(output).then(utils.extract).then (contents) ->
			utils.expect(contents, 'dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait \n')

wary.it 'should copy a local file to an edison config partition',
	edison: EDISON
	lorem: LOREM
, (images) ->
	inputStream = fs.createReadStream(images.lorem)
	output =
		image: images.edison
		path: '/lorem.txt'

	imagefs.write(output, inputStream).then(utils.waitStream).then ->
		imagefs.read(output).then(utils.extract).then (contents) ->
			utils.expect(contents, 'Lorem ipsum dolor sit amet\n')

wary.it 'should read a config.json from a edison config partition',
	edison: EDISON
, (images) ->
	input =
		image: images.edison
		path: '/config.json'

	imagefs.read(input).then(utils.extract).then (contents) ->
		utils.expect(JSON.parse(contents), files.edison['config.json'])

wary.it 'should copy a file from a edison config partition to a local file',
	edison: EDISON
, (images) ->
	input =
		image: images.edison
		path: '/config.json'

	output = path.join(__dirname, 'output.tmp')

	imagefs.read(input).then (inputStream) ->
		return inputStream.pipe(fs.createWriteStream(output))
	.then(utils.waitStream).then ->
		fs.createReadStream(output)
	.then(utils.extract).then (contents) ->
		utils.expect(JSON.parse(contents), files.edison['config.json'])
		fs.unlinkAsync(output)

wary.run().catch (error) ->
	console.error(error, error.stack)
	process.exit(1)
