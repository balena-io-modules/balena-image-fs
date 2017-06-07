_ = require('lodash')
Promise = require('bluebird')
filedisk = require('file-disk')
fs = Promise.promisifyAll(require('fs'))
path = require('path')
wary = require('wary')
imagefs = require('../lib/imagefs')
utils = require('./utils')
files = require('./images/files.json')

RASPBERRYPI = path.join(__dirname, 'images', 'raspberrypi.img')
EDISON = path.join(__dirname, 'images', 'edison-config.img')
LOREM = path.join(__dirname, 'images', 'lorem.txt')

objectToArray = (obj) ->
	# Converts {'0': 'zero', '1': 'one'} to ['zero', 'one']
	Object.keys(obj).map(Number).sort().map (key) ->
		obj[key]

testFilename = (title, fn, images...) ->
	filenames = _.pluck(images, 'image')
	wary.it title, filenames, (tmpFilenames) ->
		tmpFilenames = objectToArray(tmpFilenames)
		images = images.map (image, idx) ->
			image.image = tmpFilenames[idx]
			image
		fn(images...)

testFileDisk = (title, fn, images...) ->
	filenames = _.pluck(images, 'image')
	wary.it "#{title} (filedisk)", filenames, (tmpFilenames) ->
		tmpFilenames = objectToArray(tmpFilenames)
		fds = tmpFilenames.map (filename) ->
			filedisk.openFile(filename, 'r+')
		Promise.using fds, (fds) ->
			images = images.map (image, idx) ->
				image.image = new filedisk.FileDisk(fds[idx])
				image
			fn(images...)

testBoth = (title, fn, images...) ->
	Promise.all([
		testFilename(title, fn, images...)
		testFileDisk(title, fn, images...)
	])

testBoth(
	'should list files from a raspberrypi image'
	(input) ->
		imagefs.listDirectory(input)
		.then (contents) ->
			utils.expect contents, [
				'ds1307-rtc-overlay.dtb',
				'hifiberry-amp-overlay.dtb',
				'hifiberry-dac-overlay.dtb',
				'hifiberry-dacplus-overlay.dtb',
				'hifiberry-digi-overlay.dtb',
				'iqaudio-dac-overlay.dtb',
				'iqaudio-dacplus-overlay.dtb',
				'lirc-rpi-overlay.dtb',
				'pcf8523-rtc-overlay.dtb',
				'pps-gpio-overlay.dtb',
				'w1-gpio-overlay.dtb',
				'w1-gpio-pullup-overlay.dtb'
			]
	{
		image: RASPBERRYPI
		partition:
			primary: 1
		path: '/overlays'
	}
)

testBoth(
	'should read a config.json from a raspberrypi'
	(input) ->
		imagefs.read(input)
		.then(utils.extract)
		.then (contents) ->
			utils.expect(JSON.parse(contents), files.raspberrypi['config.json'])
	{
		image: RASPBERRYPI
		partition:
			primary: 4
			logical: 1
		path: '/config.json'
	}
)

testBoth(
	'should read a config.json from a raspberrypi using readFile'
	(input) ->
		imagefs.readFile(input)
		.then (contents) ->
			utils.expect(JSON.parse(contents), files.raspberrypi['config.json'])
	{
		image: RASPBERRYPI
		partition:
			primary: 4
			logical: 1
		path: '/config.json'
	}
)

testBoth(
	'should copy files between different partitions in a raspberrypi'
	(input, output) ->
		imagefs.copy(input, output)
		.then(utils.waitStream)
		.then ->
			imagefs.read(output)
		.then(utils.extract)
		.then (contents) ->
			utils.expect(contents, 'dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait \n')
	{
		image: RASPBERRYPI
		partition:
			primary: 1
		path: '/cmdline.txt'
	}
	{
		image: RASPBERRYPI
		partition:
			primary: 4
			logical: 1
		path: '/config.json'
	}
)

testBoth(
	'should replace files between different partitions in a raspberrypi'
	(input, output) ->
		imagefs.copy(input, output)
		.then(utils.waitStream)
		.then ->
			imagefs.read(output)
		.then(utils.extract)
		.then (contents) ->
			utils.expect(contents, 'dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait \n')
	{
		image: RASPBERRYPI
		partition:
			primary: 1
		path: '/cmdline.txt'
	}
	{
		image: RASPBERRYPI
		partition:
			primary: 4
			logical: 1
		path: '/cmdline.txt'
	}
)

testBoth(
	'should copy a local file to a raspberry pi partition'
	(output) ->
		inputStream = fs.createReadStream(LOREM)
		imagefs.write(output, inputStream)
		.then(utils.waitStream)
		.then ->
			imagefs.read(output)
		.then(utils.extract)
		.then (contents) ->
			utils.expect(contents.replace('\r', ''), 'Lorem ipsum dolor sit amet\n')
	{
		image: RASPBERRYPI
		partition:
			primary: 4
			logical: 1
		path: '/cmdline.txt'
	}
)

testBoth(
	'should copy text to a raspberry pi partition using writeFile'
	(output) ->
		imagefs.writeFile(output, 'Lorem ipsum dolor sit amet\n')
		.then ->
			imagefs.readFile(output)
		.then (contents) ->
			utils.expect(contents.replace('\r', ''), 'Lorem ipsum dolor sit amet\n')
	{
		image: RASPBERRYPI
		partition:
			primary: 4
			logical: 1
		path: '/lorem.txt'
	}
)

testBoth(
	'should copy a file from a raspberry pi partition to a local file'
	(input) ->
		output = path.join(__dirname, 'output.tmp')
		imagefs.read(input).then (inputStream) ->
			return inputStream.pipe(fs.createWriteStream(output))
		.then(utils.waitStream)
		.then ->
			fs.createReadStream(output)
		.then(utils.extract)
		.then (contents) ->
			utils.expect(contents, 'dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait \n')
			fs.unlinkAsync(output)
	{
		image: RASPBERRYPI
		partition:
			primary: 1
		path: '/cmdline.txt'
	}
)

testBoth(
	'should replace a file in an edison config partition with a local file'
	(output) ->
		inputStream = fs.createReadStream(LOREM)
		imagefs.write(output, inputStream)
		.then(utils.waitStream)
		.then ->
			imagefs.read(output)
		.then(utils.extract)
		.then (contents) ->
			utils.expect(contents.replace('\r', ''), 'Lorem ipsum dolor sit amet\n')
	{
		image: EDISON
		path: '/config.json'
	}
)

testBoth(
	'should copy a file from an edison partition to a raspberry pi'
	(input, output) ->
		imagefs.copy(input, output)
		.then(utils.waitStream)
		.then ->
			imagefs.read(output)
		.then(utils.extract)
		.then (contents) ->
			utils.expect(JSON.parse(contents), files.edison['config.json'])
	{
		image: EDISON
		path: '/config.json'
	}
	{
		image: RASPBERRYPI
		partition:
			primary: 4
			logical: 1
		path: '/edison-config.json'
	}
)

testBoth(
	'should copy a file from a raspberry pi to an edison config partition'
	(input, output) ->
		imagefs.copy(input, output)
		.then(utils.waitStream)
		.then ->
			imagefs.read(output)
		.then(utils.extract)
		.then (contents) ->
			utils.expect(contents, 'dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait \n')
	{
		image: RASPBERRYPI
		partition:
			primary: 1
		path: '/cmdline.txt'
	}
	{
		image: EDISON
		path: '/config.json'
	}
)

testBoth(
	'should copy a local file to an edison config partition'
	(output) ->
		inputStream = fs.createReadStream(LOREM)
		imagefs.write(output, inputStream)
		.then(utils.waitStream)
		.then ->
			imagefs.read(output)
		.then(utils.extract)
		.then (contents) ->
			utils.expect(contents, 'Lorem ipsum dolor sit amet\n')
	{
		image: EDISON
		path: '/lorem.txt'
	}
)

testBoth(
	'should read a config.json from a edison config partition'
	(input) ->
		imagefs.read(input)
		.then(utils.extract)
		.then (contents) ->
			utils.expect(JSON.parse(contents), files.edison['config.json'])
	{
		image: EDISON
		path: '/config.json'
	}
)

testBoth(
	'should copy a file from a edison config partition to a local file'
	(input) ->
		output = path.join(__dirname, 'output.tmp')
		imagefs.read(input)
		.then (inputStream) ->
			inputStream.pipe(fs.createWriteStream(output))
		.then(utils.waitStream)
		.then ->
			fs.createReadStream(output)
		.then(utils.extract)
		.then (contents) ->
			utils.expect(JSON.parse(contents), files.edison['config.json'])
			fs.unlinkAsync(output)
	{
		image: EDISON
		path: '/config.json'
	}
)

testBoth(
	'should replace a file in a raspberry pi partition'
	(output) ->
		inputStream = fs.createReadStream(LOREM)
		imagefs.write(output, inputStream)
		.then(utils.waitStream)
		.then ->
			imagefs.replace(output, 'Lorem', 'Elementum')
		.then(utils.waitStream)
		.then ->
			imagefs.read(output)
		.then(utils.extract)
		.then (contents) ->
			utils.expect(contents, 'Elementum ipsum dolor sit amet\n')
	{
		image: RASPBERRYPI
		partition:
			primary: 1
		path: '/lorem.txt'
	}
)

testBoth(
	'should replace cmdline.txt in a raspberry pi partition'
	(cmdline) ->
		imagefs.replace(cmdline, 'lpm_enable=0', 'lpm_enable=1')
		.then(utils.waitStream)
		.then ->
			imagefs.read(cmdline)
		.then(utils.extract)
		.then (contents) ->
			utils.expect(contents, 'dwc_otg.lpm_enable=1 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait \n')
	{
		image: RASPBERRYPI
		partition:
			primary: 1
		path: '/cmdline.txt'
	}
)

testBoth(
	'should replace a file in a raspberry pi partition with a regex'
	(output) ->
		inputStream = fs.createReadStream(LOREM)
		imagefs.write(output, inputStream)
		.then(utils.waitStream)
		.then ->
			imagefs.replace(output, /m/g, 'n')
		.then(utils.waitStream)
		.then ->
			imagefs.read(output)
		.then(utils.extract)
		.then (contents) ->
			utils.expect(contents, 'Loren ipsun dolor sit anet\n')
	{
		image: RASPBERRYPI
		partition:
			primary: 1
		path: '/lorem.txt'
	}
)

testBoth(
	'should replace a file in an edison partition'
	(output) ->
		inputStream = fs.createReadStream(LOREM)
		imagefs.write(output, inputStream)
		.then(utils.waitStream)
		.then ->
			imagefs.replace(output, 'Lorem', 'Elementum')
		.then(utils.waitStream)
		.then ->
			imagefs.read(output)
		.then(utils.extract)
		.then (contents) ->
			utils.expect(contents, 'Elementum ipsum dolor sit amet\n')
	{
		image: EDISON
		path: '/lorem.txt'
	}
)

testBoth(
	'should replace a file in an edison partition with a regex'
	(output) ->
		inputStream = fs.createReadStream(LOREM)
		imagefs.write(output, inputStream)
		.then(utils.waitStream)
		.then ->
			imagefs.replace(output, /m/g, 'n')
		.then(utils.waitStream)
		.then ->
			imagefs.read(output)
		.then(utils.extract)
		.then (contents) ->
			utils.expect(contents, 'Loren ipsun dolor sit anet\n')
	{
		image: EDISON
		path: '/lorem.txt'
	}
)

wary.run().catch (error) ->
	console.error(error, error.stack)
	process.exit(1)
