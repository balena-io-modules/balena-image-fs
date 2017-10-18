_ = require('lodash')
Promise = require('bluebird')
filedisk = require('file-disk')
fs = Promise.promisifyAll(require('fs'))
path = require('path')
wary = require('wary')
ext2fs = Promise.promisifyAll(require('ext2fs'))

imagefs = require('../lib/imagefs')
utils = require('../lib/utils')
files = require('./images/files.json')

RASPBERRYPI = path.join(__dirname, 'images', 'raspberrypi.img')
EDISON = path.join(__dirname, 'images', 'edison-config.img')
RAW_EXT2 = path.join(__dirname, 'images', 'ext2.img')
LOREM = path.join(__dirname, 'images', 'lorem.txt')
LOREM_CONTENT = fs.readFileSync(LOREM, 'utf8')
CMDLINE_CONTENT = 'dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait \n'
RASPBERRY_FIRST_PARTITION_FILES = [
	'.Trashes',
	'._.Trashes',
	'._bcm2708-rpi-b-plus.dtb',
	'._bcm2708-rpi-b.dtb',
	'._bcm2709-rpi-2-b.dtb',
	'._bcm2835-bootfiles-20150206.stamp',
	'._bootcode.bin',
	'._cmdline.txt',
	'._config.txt',
	'._fixup.dat',
	'._fixup_cd.dat',
	'._fixup_x.dat',
	'._image-version-info',
	'._kernel7.img',
	'._overlays',
	'._start.elf',
	'._start_cd.elf',
	'._start_x.elf',
	'BOOTCODE.BIN',
	'CMDLINE.TXT',
	'CONFIG.TXT',
	'FIXUP.DAT',
	'FIXUP_CD.DAT',
	'FIXUP_X.DAT',
	'KERNEL7.IMG',
	'OVERLAYS',
	'START.ELF',
	'START_CD.ELF',
	'START_X.ELF',
	'bcm2708-rpi-b-plus.dtb',
	'bcm2708-rpi-b.dtb',
	'bcm2709-rpi-2-b.dtb',
	'bcm2835-bootfiles-20150206.stamp',
	'image-version-info'
]

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
	'should list files from a fat partition in a raspberrypi image'
	(input) ->
		imagefs.listDirectory(input)
		.then (contents) ->
			utils.expect contents, [
				'._ds1307-rtc-overlay.dtb',
				'._hifiberry-amp-overlay.dtb',
				'._hifiberry-dac-overlay.dtb',
				'._hifiberry-dacplus-overlay.dtb',
				'._hifiberry-digi-overlay.dtb',
				'._iqaudio-dac-overlay.dtb',
				'._iqaudio-dacplus-overlay.dtb',
				'._lirc-rpi-overlay.dtb',
				'._pcf8523-rtc-overlay.dtb',
				'._pps-gpio-overlay.dtb',
				'._w1-gpio-overlay.dtb',
				'._w1-gpio-pullup-overlay.dtb',
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
		partition: 1
		path: '/overlays'
	}
)

testBoth(
	'should list files from an ext4 partition in a raspberrypi image'
	(input) ->
		imagefs.listDirectory(input)
		.then (contents) ->
			utils.expect(contents, [ 'lost+found', '1' ])
	{
		image: RASPBERRYPI
		partition: 6
		path: '/'
	}
)

testBoth(
	'should read a config.json from a raspberrypi'
	(input) ->
		Promise.using imagefs.read(input), (stream) ->
			utils.extract(stream)
		.then (contents) ->
			utils.expect(JSON.parse(contents), files.raspberrypi['config.json'])
	{
		image: RASPBERRYPI
		partition: 5
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
		partition: 5
		path: '/config.json'
	}
)

testBoth(
	'should fail cleanly trying to read a missing file on a raspberrypi'
	(input) ->
		Promise.using imagefs.read(input), (stream) ->
			utils.extract(stream)
		.then (contents) ->
			throw new Error('Should not successfully return contents for a missing file!')
		.catch (e) ->
			utils.expect(e.code, 'NOENT')
	{
		image: RASPBERRYPI
		partition: 5
		path: '/non-existent-file.txt'
	}
)

testBoth(
	'should copy files between different partitions in a raspberrypi'
	(input, output) ->
		imagefs.copy(input, output)
		.then ->
			imagefs.readFile(output)
		.then (contents) ->
			utils.expect(contents, CMDLINE_CONTENT)
	{
		image: RASPBERRYPI
		partition: 1
		path: '/cmdline.txt'
	}
	{
		image: RASPBERRYPI
		partition: 5
		path: '/config.json'
	}
)

testBoth(
	'should copy files from fat to ext partitions in a raspberrypi'
	(input, output) ->
		imagefs.copy(input, output)
		.then ->
			imagefs.readFile(output)
		.then (contents) ->
			utils.expect(contents, CMDLINE_CONTENT)
	{
		image: RASPBERRYPI
		partition: 1
		path: '/cmdline.txt'
	}
	{
		image: RASPBERRYPI
		partition: 6
		path: '/cmdline.txt'
	}
)

testBoth(
	'should copy files from ext to fat partitions in a raspberrypi'
	(input, output) ->
		imagefs.copy(input, output)
		.then ->
			imagefs.readFile(output)
		.then (contents) ->
			utils.expect(contents, 'one\n')
	{
		image: RASPBERRYPI
		partition: 6
		path: '/1'
	}
	{
		image: RASPBERRYPI
		partition: 1
		path: '/1'
	}
)

testBoth(
	'should replace files between different partitions in a raspberrypi'
	(input, output) ->
		imagefs.copy(input, output)
		.then ->
			imagefs.readFile(output)
		.then (contents) ->
			utils.expect(contents, CMDLINE_CONTENT)
	{
		image: RASPBERRYPI
		partition: 1
		path: '/cmdline.txt'
	}
	{
		image: RASPBERRYPI
		partition: 5
		path: '/cmdline.txt'
	}
)

testBoth(
	'should copy a local file to a raspberry pi fat partition'
	(output) ->
		inputStream = fs.createReadStream(LOREM)
		imagefs.write(output, inputStream)
		.then ->
			imagefs.readFile(output)
		.then (contents) ->
			utils.expect(contents, LOREM_CONTENT)
	{
		image: RASPBERRYPI
		partition: 5
		path: '/cmdline.txt'
	}
)

testBoth(
	'should copy a local file to a raspberry pi ext partition'
	(output) ->
		inputStream = fs.createReadStream(LOREM)
		imagefs.write(output, inputStream)
		.then ->
			imagefs.readFile(output)
		.then (contents) ->
			utils.expect(contents, LOREM_CONTENT)
	{
		image: RASPBERRYPI
		partition: 6
		path: '/cmdline.txt'
	}
)

testBoth(
	'should copy text to a raspberry pi partition using writeFile'
	(output) ->
		imagefs.writeFile(output, LOREM_CONTENT)
		.then ->
			imagefs.readFile(output)
		.then (contents) ->
			utils.expect(contents, LOREM_CONTENT)
	{
		image: RASPBERRYPI
		partition: 5
		path: '/lorem.txt'
	}
)

testBoth(
	'should copy a file from a raspberry pi partition to a local file'
	(input) ->
		output = path.join(__dirname, 'output.tmp')
		Promise.using imagefs.read(input), (inputStream) ->
			out = fs.createWriteStream(output)
			inputStream.pipe(out)
			utils.waitStream(out)
		.then ->
			fs.createReadStream(output)
		.then(utils.extract)
		.then (contents) ->
			utils.expect(contents, CMDLINE_CONTENT)
			fs.unlinkAsync(output)
	{
		image: RASPBERRYPI
		partition: 1
		path: '/cmdline.txt'
	}
)

testBoth(
	'should replace a file in an edison config partition with a local file'
	(output) ->
		inputStream = fs.createReadStream(LOREM)
		imagefs.write(output, inputStream)
		.then ->
			imagefs.readFile(output)
		.then (contents) ->
			utils.expect(contents, LOREM_CONTENT)
	{
		image: EDISON
		path: '/config.json'
	}
)

testBoth(
	'should copy a file from an edison partition to a raspberry pi'
	(input, output) ->
		imagefs.copy(input, output)
		.then ->
			imagefs.readFile(output)
		.then (contents) ->
			utils.expect(JSON.parse(contents), files.edison['config.json'])
	{
		image: EDISON
		path: '/config.json'
	}
	{
		image: RASPBERRYPI
		partition: 5
		path: '/edison-config.json'
	}
)

testBoth(
	'should copy a file from a raspberry pi to an edison config partition'
	(input, output) ->
		imagefs.copy(input, output)
		.then ->
			imagefs.readFile(output)
		.then (contents) ->
			utils.expect(contents, CMDLINE_CONTENT)
	{
		image: RASPBERRYPI
		partition: 1
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
		.then ->
			imagefs.readFile(output)
		.then (contents) ->
			utils.expect(contents, LOREM_CONTENT)
	{
		image: EDISON
		path: '/lorem.txt'
	}
)

testBoth(
	'should read a config.json from a edison config partition'
	(input) ->
		Promise.using imagefs.read(input), (stream) ->
			utils.extract(stream)
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
		Promise.using imagefs.read(input), (inputStream) ->
			out = fs.createWriteStream(output)
			inputStream.pipe(out)
			utils.waitStream(out)
		.then ->
			fs.readFileAsync(output, 'utf8')
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
		search = 'Lorem'
		replacement = 'Elementum'
		inputStream = fs.createReadStream(LOREM)
		imagefs.write(output, inputStream)
		.then ->
			imagefs.replace(output, search, replacement)
		.then ->
			imagefs.readFile(output)
		.then (contents) ->
			utils.expect(contents, LOREM_CONTENT.replace(search, replacement))
	{
		image: RASPBERRYPI
		partition: 1
		path: '/lorem.txt'
	}
)

testBoth(
	'should replace cmdline.txt in a raspberry pi partition'
	(cmdline) ->
		search = 'lpm_enable=0'
		replacement = 'lpm_enable=1'
		imagefs.replace(cmdline, search, replacement)
		.then ->
			imagefs.readFile(cmdline)
		.then (contents) ->
			utils.expect(contents, CMDLINE_CONTENT.replace(search, replacement))
	{
		image: RASPBERRYPI
		partition: 1
		path: '/cmdline.txt'
	}
)

testBoth(
	'should replace a file in a raspberry pi partition with a regex'
	(output) ->
		search = /m/g
		replacement = 'n'
		inputStream = fs.createReadStream(LOREM)
		imagefs.write(output, inputStream)
		.then ->
			imagefs.replace(output, search, replacement)
		.then ->
			imagefs.readFile(output)
		.then (contents) ->
			utils.expect(contents, LOREM_CONTENT.replace(search, replacement))
	{
		image: RASPBERRYPI
		partition: 1
		path: '/lorem.txt'
	}
)

testBoth(
	'should replace a file in an edison partition'
	(output) ->
		search = 'Lorem'
		replacement = 'Elementum'
		inputStream = fs.createReadStream(LOREM)
		imagefs.write(output, inputStream)
		.then ->
			imagefs.replace(output, search, replacement)
		.then ->
			imagefs.readFile(output)
		.then (contents) ->
			utils.expect(contents, LOREM_CONTENT.replace(search, replacement))
	{
		image: EDISON
		path: '/lorem.txt'
	}
)

testBoth(
	'should replace a file in an edison partition with a regex'
	(output) ->
		search = /m/g
		replacement = 'n'
		inputStream = fs.createReadStream(LOREM)
		imagefs.write(output, inputStream)
		.then ->
			imagefs.replace(output, search, replacement)
		.then ->
			imagefs.readFile(output)
		.then (contents) ->
			utils.expect(contents, LOREM_CONTENT.replace(search, replacement))
	{
		image: EDISON
		path: '/lorem.txt'
	}
)

testBoth(
	'should return a node fs like interface for fat partitions'
	(input) ->
		Promise.using imagefs.interact(input.image, input.partition), (fs_) ->
			fs_.readdirAsync('/')
			.then (files) ->
				utils.expect(files, RASPBERRY_FIRST_PARTITION_FILES)
	{
		image: RASPBERRYPI
		partition: 1
	}
)

testBoth(
	'should return a node fs like interface for ext partitions'
	(input) ->
		Promise.using imagefs.interact(input.image, input.partition), (fs_) ->
			fs_.readdirAsync('/')
			.then (files) ->
				utils.expect(files, [ 'lost+found', '1' ])
	{
		image: RASPBERRYPI
		partition: 6
	}
)

testBoth(
	'should return a node fs like interface for raw ext partitions'
	(input) ->
		Promise.using imagefs.interact(input.image), (fs_) ->
			fs_.readdirAsync('/')
			.then (files) ->
				utils.expect(files, [ 'lost+found', '1' ])
	{
		image: RAW_EXT2
	}
)

testBoth(
	'should return a node fs like interface for raw fat partitions'
	(input) ->
		Promise.using imagefs.interact(input.image), (fs_) ->
			fs_.readdirAsync('/')
			.then (files) ->
				utils.expect(files, [ 'config.json' ])
	{
		image: EDISON
	}
)

wary.run()
.catch (error) ->
	console.error(error, error.stack)
	process.exit(1)
