###
Copyright 2016 Resin.io

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
###

partitioninfo = require('partitioninfo')
Promise = require('bluebird')
fs = Promise.promisifyAll(require('fs'))
fatfs = require('fatfs')

SECTOR_SIZE = 512

###*
# @summary Get a fatfs driver given a file descriptor
# @protected
# @function
#
# @param {Object} fd - file descriptor
# @param {Number} offset - offset of the image
# @param {Number} size - size of the image
# @returns {Object} the fatfs driver
#
# @example
# fatDriver = driver.getDriver(fd, 0, 2048)
###
exports.getDriver = (fd, offset, size) ->
	return {
		sectorSize: SECTOR_SIZE
		numSectors: size / SECTOR_SIZE
		readSectors: (sector, dest, callback) ->
			position = offset + sector * SECTOR_SIZE
			fs.read fd, dest, 0, dest.length, position, (error, bytesRead, buffer) ->
				return callback(error, buffer)

		writeSectors: (sector, data, callback) ->
			position = offset + sector * SECTOR_SIZE
			fs.write(fd, data, 0, data.length, position, callback)
	}

###*
# @summary Get a fatfs driver from a file
# @protected
# @function
#
# @param {String} file - file path
# @param {Number} offset - offset of the image
# @param {Number} size - size of the image
# @returns {Promise<Object>} fatfs filesystem object
#
# @todo Test this.
#
# @example
# driver.createDriverFromFile('my/file').then (driver) ->
# 	console.log(driver)
###
exports.createDriverFromFile = (file, offset, size) ->
	fs.openAsync(file, 'r+').then (fd) ->
		driver = exports.getDriver(fd, offset, size)
		fat = fatfs.createFileSystem(driver)

		# Not closing it might cause EPERM errors
		# when unlinking the file
		fat.closeDriver = ->
			return fs.closeAsync(fd)

		Promise.fromNode (callback) ->
			fat.on('error', callback)
			fat.on 'ready', ->
				return callback(null, Promise.promisifyAll(fat))

###*
# @summary Get a fs instance pointing to a FAT partition
# @protected
# @function
#
# @description
# If no partition definition is passed, an hddimg partition file is assumed.
#
# @param {String} image - image path
# @param {Object} [definition] - partition definition
#
# @returns {Promise<Object>} filesystem object
#
# @example
# driver.interact('foo/bar.img', primary: 1).then (fs) ->
# 	fs.readdirAsync('/').then (files) ->
# 		console.log(files)
###
exports.interact = (image, definition) ->
	Promise.try ->
		return partitioninfo.get(image, definition) if definition?

		# Handle partition files (*.hddimg)
		return fs.statAsync(image).get('size').then (size) ->
			return { offset: 0, size: size }

	.then (information) ->
		return exports.createDriverFromFile(image, information.offset, information.size)
