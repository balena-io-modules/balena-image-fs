Bluebird = require('bluebird')
filedisk = require('file-disk')
fs = require('fs')
path = require('path')
wary = require('wary')
assert = require('assert')
util = require('util')
chalk = require('chalk')

imagefs = require('../lib/imagefs')
files = require('./images/files.json')

RASPBERRYPI = path.join(__dirname, 'images', 'raspberrypi.img')
EDISON = path.join(__dirname, 'images', 'edison-config.img')
RAW_EXT2 = path.join(__dirname, 'images', 'ext2.img')
LOREM = path.join(__dirname, 'images', 'lorem.txt')
LOREM_CONTENT = fs.readFileSync(LOREM, 'utf8')
GPT = path.join(__dirname, 'images', 'gpt.img')
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

waitStream = (stream) ->
	new Promise (resolve, reject) ->
		stream.on('error', reject)
		stream.on('close', resolve)

extract = (stream) ->
	chunks = []
	new Promise (resolve, reject) ->
		stream.on 'error', reject
		stream.on 'data', (chunk) ->
			chunks.push(chunk)
		stream.on 'end', ->
			resolve(Buffer.concat(chunks))

expect = (input, output) ->
	assert.deepEqual(input, output, chalk.red("Expected #{util.inspect(input)} to equal #{util.inspect(output)}"))

testFilename = (title, fn, image) ->
	wary.it title, { file: image.image }, (tmpFilenames) ->
		imagefs.interact tmpFilenames.file, image.partition, ($fs) ->
			fn(Bluebird.promisifyAll($fs))

testFileDisk = (title, fn, image) ->
	wary.it "#{title} (filedisk)", { file: image.image }, (tmpFilenames) ->
		filedisk.withOpenFile tmpFilenames.file, 'r+', (handle) ->
			disk = new filedisk.FileDisk(handle)
			imagefs.interact disk, image.partition, ($fs) ->
				fn(Bluebird.promisifyAll($fs))

testBoth = (title, fn, image) ->
	Promise.all([
		testFilename(title, fn, image)
		testFileDisk(title, fn, image)
	])

wary.it 'should throw an error when the partition number is 0', { file: RASPBERRYPI }, (tmpFilenames) ->
	imagefs.interact tmpFilenames.file, 0, ($fs) ->
		# this should not work
		expect(false, true)
	.catch (e) ->
		expect(e.message, 'The partition number must be at least 1.')

testBoth(
	'should list files from a fat partition in a raspberrypi image'
	($fs) ->
		$fs.readdirAsync('/overlays')
		.then (contents) ->
			expect contents, [
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
	}
)

testBoth(
	'should list files from an ext4 partition in a raspberrypi image'
	($fs) ->
		$fs.readdirAsync('/')
		.then (contents) ->
			expect(contents, [ 'lost+found', '1' ])
	{
		image: RASPBERRYPI
		partition: 6
	}
)

testBoth(
	'should read a config.json from a raspberrypi'
	($fs) ->
		stream = $fs.createReadStream('/config.json')
		extract(stream)
		.then (contents) ->
			expect(JSON.parse(contents), files.raspberrypi['config.json'])
	{
		image: RASPBERRYPI
		partition: 5
	}
)

testBoth(
	'should read a config.json from a raspberrypi using readFile'
	($fs) ->
		$fs.readFileAsync('/config.json')
		.then (contents) ->
			expect(JSON.parse(contents), files.raspberrypi['config.json'])
	{
		image: RASPBERRYPI
		partition: 5
	}
)

testBoth(
	'should fail cleanly trying to read a missing file on a raspberrypi'
	($fs) ->
		stream = $fs.createReadStream('/non-existent-file.txt')
		extract(stream)
		.then (contents) ->
			throw new Error('Should not successfully return contents for a missing file!')
		.catch (e) ->
			expect(e.code, 'NOENT')
	{
		image: RASPBERRYPI
		partition: 5
	}
)

testBoth(
	'should copy a local file to a raspberry pi fat partition'
	($fs) ->
		output = '/cmdline.txt'
		inputStream = fs.createReadStream(LOREM)
		outputStream = $fs.createWriteStream(output)
		inputStream.pipe(outputStream)
		waitStream(outputStream)
		.then ->
			$fs.readFileAsync(output, { encoding: 'utf8' })
		.then (contents) ->
			expect(contents, LOREM_CONTENT)
	{
		image: RASPBERRYPI
		partition: 5
	}
)

testBoth(
	'should copy a local file to a raspberry pi ext partition'
	($fs) ->
		output = '/cmdline.txt'
		inputStream = fs.createReadStream(LOREM)
		outputStream = $fs.createWriteStream(output)
		inputStream.pipe(outputStream)
		waitStream(outputStream)
		.then ->
			$fs.readFileAsync(output, { encoding: 'utf8' })
		.then (contents) ->
			expect(contents, LOREM_CONTENT)
	{
		image: RASPBERRYPI
		partition: 6
	}
)

testBoth(
	'should copy text to a raspberry pi partition using writeFile'
	($fs) ->
		output = '/lorem.txt'
		$fs.writeFileAsync(output, LOREM_CONTENT)
		.then ->
			$fs.readFileAsync(output, { encoding: 'utf8' })
		.then (contents) ->
			expect(contents, LOREM_CONTENT)
	{
		image: RASPBERRYPI
		partition: 5
	}
)

testBoth(
	'should copy a local file to an edison config partition'
	($fs) ->
		output = '/lorem.txt'
		inputStream = fs.createReadStream(LOREM)
		outputStream = $fs.createWriteStream(output)
		inputStream.pipe(outputStream)
		waitStream(outputStream)
		.then ->
			$fs.readFileAsync(output, { encoding: 'utf8' })
		.then (contents) ->
			expect(contents, LOREM_CONTENT)
	{
		image: EDISON
	}
)

testBoth(
	'should read a config.json from a edison config partition'
	($fs) ->
		stream = $fs.createReadStream('/config.json')
		extract(stream)
		.then (contents) ->
			expect(JSON.parse(contents), files.edison['config.json'])
	{
		image: EDISON
	}
)

testBoth(
	'should return a node fs like interface for fat partitions'
	($fs) ->
		$fs.readdirAsync('/')
		.then (files) ->
			expect(files, RASPBERRY_FIRST_PARTITION_FILES)
	{
		image: RASPBERRYPI
		partition: 1
	}
)

testBoth(
	'should return a node fs like interface for ext partitions'
	($fs) ->
		$fs.readdirAsync('/')
		.then (files) ->
			expect(files, [ 'lost+found', '1' ])
	{
		image: RASPBERRYPI
		partition: 6
	}
)

testBoth(
	'should return a node fs like interface for raw ext partitions'
	($fs) ->
		$fs.readdirAsync('/')
		.then (files) ->
			expect(files, [ 'lost+found', '1' ])
	{
		image: RAW_EXT2
	}
)

testBoth(
	'should return a node fs like interface for raw fat partitions'
	($fs) ->
		$fs.readdirAsync('/')
		.then (files) ->
			expect(files, [ 'config.json' ])
	{
		image: EDISON
	}
)

testBoth(
	'should return a node fs like interface for fat partitions held in gpt typed images'
	($fs) ->
		$fs.readdirAsync('/')
		.then (files) ->
			expect(files, [ 'fat.file' ])
	{
		image: GPT
		partition: 1
	}
)

testBoth(
	'should return a node fs like interface for ext partitions held in gpt typed images'
	($fs) ->
		$fs.readdirAsync('/')
		.then (files) ->
			expect(files, [ 'lost+found', 'ext4.file' ])
	{
		image: GPT
		partition: 2
	}
)

wary.run()
.catch (error) ->
	console.error(error, error.stack)
	process.exitCode = 1
