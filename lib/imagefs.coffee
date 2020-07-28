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

###*
# @module imagefs
###

Promise = require('bluebird')
filedisk = require('file-disk')
replaceStream = require('replacestream')
stream = require('stream')

driver = require('./driver')
utils = require('./utils')

checkImageType = (image) ->
	if not (typeof image == 'string' or image instanceof filedisk.Disk)
		throw new Error('image must be a String (file path) or a filedisk.Disk instance')

composeDisposers = (outerDisposer, createInnerDisposer) ->
	Promise.resolve(outerDisposer)
	.then (outerDisposer) ->
		outerDisposer._promise
		.then (outerResult) ->
			Promise.try ->
				Promise.resolve(createInnerDisposer(outerResult))
				.then (innerDisposer) ->
					innerDisposer._promise
					.then ->
						[ innerDisposer, innerDisposer._promise ]
			.catch (err) ->
				outerDisposer._data(outerResult)
				throw err
			.spread (innerDisposer, innerResult) ->
				Promise.resolve(innerResult)
				.disposer (innerResult) ->
					Promise.resolve(innerDisposer._data(innerResult))
					.then ->
						outerDisposer._data(outerResult)

###*
# @summary Get a bluebird.disposer of a node fs like interface for a partition
# @function
# @public
#
# @param {String|filedisk.Disk} disk - path to the image or filedisk.Disk instance
# @param {Number} partition - partition number
#
# @returns {bluebird.disposer<fs>} node fs like interface
#
# @example
#
# Promise.using imagefs.interact('/foo/bar.img', 5), (fs) ->
#   fs.readFileAsync('/bar/qux')
#   .then (contents) ->
#     console.log(contents)
###
exports.interact = (disk, partition) ->
	checkImageType(disk)
	if typeof disk == 'string'
		composeDisposers(
			filedisk.openFile(disk, 'r+')
			(fd) ->
				disk = new filedisk.FileDisk(fd, true)
				driver.interact(disk, partition)
		)
	else if disk instanceof filedisk.Disk
		driver.interact(disk, partition)

read = (disk, partition, path) ->
	composeDisposers(
		driver.interact(disk, partition)
		(fs_) ->
			readStream = null
			outputStream = new stream.PassThrough()

			startReadStream = ->
				try
					readStream = fs_.createReadStream(path, autoClose: false)
				catch e
					outputStream.emit('error', e)
					return

				readStream.on 'error', (err) ->
					outputStream.emit('error', err)

				readStream.pipe(outputStream)

			# We don't start the stream until somebody else starts listening
			# Delayed slightly, as this event fires _before_ the listener is added
			outputStream.once('newListener', -> process.nextTick(startReadStream))

			Promise.resolve(outputStream)
			.disposer (stream) ->
				outputStream.end()

				# streams returned by fatfs do not have a close method
				if readStream? && readStream.closeAsync
					readStream.closeAsync()
	)

###*
# @summary Get a device file readable stream
# @function
# @public
#
# @param {Object} definition - device path definition
# @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
# @param {Number} [definition.partition] - partition number
# @param {String} definition.path - file path
#
# @returns {bluebird.disposer<ReadStream>} file stream
#
# @example
# disposer = imagefs.read
# 	image: '/foo/bar.img'
# 	partition: 5
# 	path: '/baz/qux'
#
# Promise.using disposer, (stream) ->
#   out = fs.createWriteStream('/bar/qux')
#   stream.pipe(out)
#   utils.waitStream(out)
###
exports.read = (definition) ->
	checkImageType(definition.image)
	if typeof definition.image == 'string'
		composeDisposers(
			filedisk.openFile(definition.image, 'r')
			(fd) ->
				disk = new filedisk.FileDisk(fd, true)
				read(disk, definition.partition, definition.path)
		)
	else if definition.image instanceof filedisk.Disk
		read(definition.image, definition.partition, definition.path)

write = (disk, partition, path, stream) ->
	Promise.using driver.interact(disk, partition), (fs_) ->
		outStream = fs_.createWriteStream(path)
		stream.pipe(outStream)
		utils.waitStream(outStream)

###*
# @summary Write a stream to a device file
# @function
# @public
#
# @param {Object} definition - device path definition
# @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
# @param {Number} [definition.partition] - partition number
# @param {String} definition.path - file path
#
# @param {ReadStream} stream - contents stream
# @returns {Promise}
#
# @example
# imagefs.write
# 	image: '/foo/bar.img'
# 	partition: 2
# 	path: '/baz/qux'
# , fs.createReadStream('/baz/qux')
###
exports.write = (definition, stream) ->
	checkImageType(definition.image)
	if typeof definition.image == 'string'
		Promise.using filedisk.openFile(definition.image, 'r+'), (fd) ->
			disk = new filedisk.FileDisk(fd, false, false)
			write(disk, definition.partition, definition.path, stream)
	else if definition.image instanceof filedisk.Disk
		write(definition.image, definition.partition, definition.path, stream)

readFile = (disk, partition, path) ->
	Promise.using driver.interact(disk, partition), (fs_) ->
		fs_.readFileAsync(path, encoding: 'utf8')

###*
# @summary Read a device file
# @function
# @public
#
# @param {Object} definition - device path definition
# @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
# @param {Number} [definition.partition] - partition number
# @param {String} definition.path - file path
#
# @returns {Promise<String>} file text
#
# @example
# imagefs.readFile
# 	image: '/foo/bar.img'
# 	partition: 5
# 	path: '/baz/qux'
# .then (contents) ->
# 	console.log(contents)
###
exports.readFile = (definition) ->
	checkImageType(definition.image)
	if typeof definition.image == 'string'
		Promise.using filedisk.openFile(definition.image, 'r'), (fd) ->
			disk = new filedisk.FileDisk(fd)
			readFile(disk, definition.partition, definition.path)
	else if definition.image instanceof filedisk.Disk
		readFile(definition.image, definition.partition, definition.path)

writeFile = (disk, partition, path, contents) ->
	Promise.using driver.interact(disk, partition), (fs_) ->
		fs_.writeFileAsync(path, contents)

###*
# @summary Write a device file
# @function
# @public
#
# @param {Object} definition - device path definition
# @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
# @param {Number} [definition.partition] - partition number
# @param {String} definition.path - file path
#
# @param {String} contents - contents string
# @returns {Promise}
#
# @example
# imagefs.writeFile
# 	image: '/foo/bar.img'
# 	partition: 2
# 	path: '/baz/qux'
# , 'foo bar baz'
###
exports.writeFile = (definition, contents) ->
	checkImageType(definition.image)
	if typeof definition.image == 'string'
		Promise.using filedisk.openFile(definition.image, 'r+'), (fd) ->
			disk = new filedisk.FileDisk(fd)
			writeFile(disk, definition.partition, definition.path, contents)
	else if definition.image instanceof filedisk.Disk
		writeFile(definition.image, definition.partition, definition.path, contents)

###*
# @summary Copy a device file
# @function
# @public
#
# @param {Object} input - input device path definition
# @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
# @param {Number} [input.partition] - partition number
# @param {String} input.path - file path
#
# @param {Object} output - output device path definition
# @param {String} output.image - path to the image
# @param {Number} [output.partition] - partition number
# @param {String} output.path - file path
#
# @returns {Promise}
#
# @example
# imagefs.copy
# 	image: '/foo/bar.img'
# 	partition: 2
# 	path: '/baz/qux'
# ,
# 	image: '/foo/bar.img'
# 	partition: 5
# 	path: '/baz/hello'
###
exports.copy = (input, output) ->
	Promise.using exports.read(input), (stream) ->
		exports.write(output, stream)

###*
# @summary Perform search and replacement in a file
# @function
# @public
#
# @param {Object} definition - device path definition
# @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
# @param {Number} [definition.partition] - partition number
# @param {String} definition.path - file path
#
# @param {(String|RegExp)} search - search term
# @param {String} replace - replace value
#
# @returns {Promise}
#
# @example
# imagefs.replace
# 	image: '/foo/bar.img'
# 	partition: 2
# 	path: '/baz/qux'
# , 'bar', 'baz'
###
exports.replace = (definition, search, replace) ->
	Promise.using exports.read(definition), (stream) ->
		replacedStream = stream.pipe(replaceStream(search, replace))
		exports.write(definition, replacedStream)

listDirectory = (disk, partition, path) ->
	Promise.using driver.interact(disk, partition), (fs_) ->
		fs_.readdirAsync(path)

###*
# @summary List the contents of a directory
# @function
# @public
#
# @param {Object} definition - device path definition
# @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
# @param {Number} [definition.partition] - partition number
# @param {String} definition.path - directory path
#
# @returns {Promise<String[]>} list of files in directory
#
# @example
# imagefs.listDirectory
# 	image: '/foo/bar.img'
# 	partition: 5
# 	path: '/my/directory'
# .then (files) ->
# 	console.log(files)
###
exports.listDirectory = (definition) ->
	checkImageType(definition.image)
	if typeof definition.image == 'string'
		Promise.using filedisk.openFile(definition.image, 'r+'), (fd) ->
			disk = new filedisk.FileDisk(fd)
			listDirectory(disk, definition.partition, definition.path)
	else if definition.image instanceof filedisk.Disk
		listDirectory(definition.image, definition.partition, definition.path)
