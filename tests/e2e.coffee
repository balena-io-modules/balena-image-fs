Promise = require('bluebird')
fs = Promise.promisifyAll(require('fs'))
assert = require('assert')
path = require('path')
scenario = require('./scenario')
imagefs = require('../lib/imagefs')

RASPBERRYPI_CONFIG_JSON =
	applicationId: '1503'
	apiKey: 'osMIXH0Yxk5dBQlN7qdB0Q3Lh5yNnvHX'
	userId: '24'
	username: 'jviotti'
	deviceType: 'raspberry-pi2'
	files:
		'network/settings': '[global]\nOfflineMode=false\n\n[WiFi]\nEnable=true\nTethering=false\n\n[Wired]\nEnable=true\nTethering=false\n\n[Bluetooth]\nEnable=true\nTethering=false'
		'network/network.config': '[service_home_ethernet]\nType = ethernet\nNameservers = 8.8.8.8,8.8.4.4'

EDISON_CONFIG_JSON =
	applicationId: '1600'
	apiKey: 'fKtNQKgc2MaCrYSyTNzztLLPLUPaaElS'
	userId: '24'
	username: 'jviotti'
	deviceType: 'intel-edison'
	wifiSsid: 'foobar'
	wifiKey: 'secret'
	apiEndpoint: 'https://api.resinstaging.io'
	appUpdatePollInterval: '60000'
	listenPort: '48484'
	mixpanelToken: 'cb974f32bab01ecc1171937026774b18'
	pubnubPublishKey: 'pub-c-6cbce8db-bfd1-4fdf-a8c8-53671ae2b226'
	pubnubSubscribeKey: 'sub-c-bbc12eba-ce4a-11e3-9782-02ee2ddab7fe'
	registryEndpoint: 'registry.resinstaging.io'
	files:
		'network/settings': '[global]\nOfflineMode=false\n\n[WiFi]\nEnable=true\nTethering=false\n\n[Wired]\nEnable=true\nTethering=false\n\n[Bluetooth]\nEnable=true\nTethering=false'
		'network/network.config': '[service_home_ethernet]\nType = ethernet\nNameservers = 8.8.8.8,8.8.4.4\n\n[service_home_wifi]\nType = wifi\nName = foobar\nPassphrase = secret\nNameservers = 8.8.8.8,8.8.4.4'

extract = (stream) ->
	return new Promise (resolve, reject) ->
		result = ''
		stream.on('error', reject)
		stream.on 'data', (chunk) ->
			result += chunk
		stream.on 'end', ->
			resolve(result)

waitStream = (stream) ->
	return new Promise (resolve, reject) ->
		stream.on('error', reject)
		stream.on('close', resolve)

scenario.add 'it should read a config.json from a raspberrypi', ->
	input = "#{@raspberrypi}(4:1):/config.json"
	imagefs.read(input).then(extract).then (contents) ->
		scenario.assert(JSON.parse(contents), RASPBERRYPI_CONFIG_JSON)

scenario.add 'it should copy files between different partitions in a raspberrypi', ->
	input = "#{@raspberrypi}(1):/cmdline.txt"
	output = "#{@raspberrypi}(4:1):/config.json"
	imagefs.copy(input, output).then(waitStream).then ->
		imagefs.read(output).then(extract).then (contents) ->
			scenario.assert(contents, 'dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait \n')

scenario.add 'it should replace files between different partitions in a raspberrypi', ->
	input = "#{@raspberrypi}(1):/cmdline.txt"
	output = "#{@raspberrypi}(4:1):/cmdline.txt"
	imagefs.copy(input, output).then(waitStream).then ->
		imagefs.read(output).then(extract).then (contents) ->
			scenario.assert(contents, 'dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait \n')

scenario.add 'it should copy a local file to a raspberry pi partition', ->
	input = @lorem
	output = "#{@raspberrypi}(4:1):/lorem.txt"
	imagefs.copy(input, output).then(waitStream).then ->
		imagefs.read(output).then(extract).then (contents) ->
			scenario.assert(contents.replace('\r', ''), 'Lorem ipsum dolor sit amet\n')

scenario.add 'it should copy a file from a raspberry pi partition to a local file', ->
	input = "#{@raspberrypi}(1):/cmdline.txt"
	output = path.join(__dirname, 'output.tmp')
	imagefs.copy(input, output).then(waitStream).then ->
		imagefs.read(output).then(extract).then (contents) ->
			scenario.assert(contents, 'dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait \n')
			fs.unlinkAsync(output)

scenario.add 'it should replace a file in an edison config partition with a local file', ->
	input = @lorem
	output = "#{@edison}:/config.json"
	imagefs.copy(input, output).then(waitStream).then ->
		imagefs.read(output).then(extract).then (contents) ->
			scenario.assert(contents.replace('\r', ''), 'Lorem ipsum dolor sit amet\n')

scenario.add 'it should copy a file from an edison partition to a raspberry pi', ->
	input = "#{@edison}:/config.json"
	output = "#{@raspberrypi}(4:1):/edison-config.json"
	imagefs.copy(input, output).then(waitStream).then ->
		imagefs.read(output).then(extract).then (contents) ->
			scenario.assert(JSON.parse(contents), EDISON_CONFIG_JSON)

scenario.add 'it should copy a file from a raspberry pi to an edison config partition', ->
	input = "#{@raspberrypi}(1):/cmdline.txt"
	output = "#{@edison}:/cmdline.txt"
	imagefs.copy(input, output).then(waitStream).then ->
		imagefs.read(output).then(extract).then (contents) ->
			scenario.assert(contents, 'dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait \n')

scenario.add 'it should copy a local file to an edison config partition', ->
	input = @lorem
	output = "#{@edison}:/lorem.txt"
	imagefs.copy(input, output).then(waitStream).then ->
		imagefs.read(output).then(extract).then (contents) ->
			scenario.assert(contents, 'Lorem ipsum dolor sit amet\n')

scenario.add 'it should read a config.json from a edison config partition', ->
	input = "#{@edison}:/config.json"
	imagefs.read(input).then(extract).then (contents) ->
		scenario.assert(JSON.parse(contents), EDISON_CONFIG_JSON)

scenario.add 'it should copy a file from a edison config partition to a local file', ->
	input = "#{@edison}:/config.json"
	output = path.join(__dirname, 'output.tmp')
	imagefs.copy(input, output).then(waitStream).then ->
		imagefs.read(output).then(extract).then (contents) ->
			scenario.assert(JSON.parse(contents), EDISON_CONFIG_JSON)
			fs.unlinkAsync(output)

scenario.run().catch (error) ->
	console.error(error, error.stack)
	process.exit(1)
