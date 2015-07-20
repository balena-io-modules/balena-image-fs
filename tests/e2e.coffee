Promise = require('bluebird')
fs = Promise.promisifyAll(require('fs'))
assert = require('assert')
path = require('path')
scenario = require('./scenario')
imagefs = require('../lib/imagefs')

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
		scenario.assert JSON.parse(contents),
			applicationId: '1503'
			apiKey: 'osMIXH0Yxk5dBQlN7qdB0Q3Lh5yNnvHX'
			userId: '24'
			username: 'jviotti'
			deviceType: 'raspberry-pi2'
			files:
				'network/settings': '[global]\nOfflineMode=false\n\n[WiFi]\nEnable=true\nTethering=false\n\n[Wired]\nEnable=true\nTethering=false\n\n[Bluetooth]\nEnable=true\nTethering=false'
				'network/network.config': '[service_home_ethernet]\nType = ethernet\nNameservers = 8.8.8.8,8.8.4.4'

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

scenario.add 'it should replace a file in an edison hddimg partition with a local file', ->
	input = @lorem
	output = "#{@edison}:/config.json"
	imagefs.copy(input, output).then(waitStream).then ->
		imagefs.read(output).then(extract).then (contents) ->
			scenario.assert(contents.replace('\r', ''), 'Lorem ipsum dolor sit amet\n')

# TODO: This test returns a RangeError: out of range index
# scenario.add 'it should copy a local file to an edison hddimg partition', ->
	# input = @lorem
	# output = "#{@edison}:/lorem.txt"
	# imagefs.copy(input, output).then(waitStream).then ->
		# imagefs.read(output).then(extract).then (contents) ->
			# scenario.assert(contents, 'Lorem ipsum dolor sit amet\n')

scenario.add 'it should read a config.json from a edison hddimg', ->
	input = "#{@edison}:/config.json"
	imagefs.read(input).then(extract).then (contents) ->
		scenario.assert JSON.parse(contents),
			applicationId: '2412'
			apiKey: 'q5RmH1GDSLkFbz8FzIOYHt9KBGlh6yad'
			userId: '175'
			username: 'jviotti',
			deviceType: 'intel-edison'
			wifiSsid: 'COMTECO-180019'
			wifiKey: 'HEZXA08464',
			files:
				'network/settings': '[global]\nOfflineMode=false\n\n[WiFi]\nEnable=true\nTethering=false\n\n[Wired]\nEnable=true\nTethering=false\n\n[Bluetooth]\nEnable=true\nTethering=false'
				'network/network.config': '[service_home_ethernet]\nType = ethernet\nNameservers = 8.8.8.8,8.8.4.4\n\n[service_home_wifi]\nType = wifi\nName = COMTECO-180019\nPassphrase = HEZXA08464\nNameservers = 8.8.8.8,8.8.4.4'

scenario.add 'it should copy a file from a edison hddimg to a local file', ->
	input = "#{@edison}:/config.json"
	output = path.join(__dirname, 'output.tmp')
	imagefs.copy(input, output).then(waitStream).then ->
		imagefs.read(output).then(extract).then (contents) ->
			scenario.assert JSON.parse(contents),
				applicationId: '2412'
				apiKey: 'q5RmH1GDSLkFbz8FzIOYHt9KBGlh6yad'
				userId: '175'
				username: 'jviotti',
				deviceType: 'intel-edison'
				wifiSsid: 'COMTECO-180019'
				wifiKey: 'HEZXA08464',
				files:
					'network/settings': '[global]\nOfflineMode=false\n\n[WiFi]\nEnable=true\nTethering=false\n\n[Wired]\nEnable=true\nTethering=false\n\n[Bluetooth]\nEnable=true\nTethering=false'
					'network/network.config': '[service_home_ethernet]\nType = ethernet\nNameservers = 8.8.8.8,8.8.4.4\n\n[service_home_wifi]\nType = wifi\nName = COMTECO-180019\nPassphrase = HEZXA08464\nNameservers = 8.8.8.8,8.8.4.4'
			fs.unlinkAsync(output)

scenario.run().catch (error) ->
	console.error(error, error.stack)
	process.exit(1)
