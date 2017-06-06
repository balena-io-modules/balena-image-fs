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
_ = require('lodash')
filedisk = require('file-disk')
fs = Promise.promisifyAll(require('fs'))
replaceStream = require('replacestream')
driver = require('./driver')

checkImageType = (image) ->
	if not (_.isString(image) or image instanceof filedisk.Disk)
		throw new Error('image must be a String (file path) or a filedisk.Disk instance')

read = (disk, partition, path) ->
	driver.interact(disk, partition)
	.then (fat) ->
		fat.createReadStream(path)

###*
# @summary Get a device file readable stream
# @function
# @public
#
# @param {Object} definition - device path definition
# @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
# @param {Object} [definition.partition] - partition definition
# @param {String} definition.path - file path
#
# @returns {Promise<ReadStream>} file stream
#
# @example
# imagefs.read
# 	image: '/foo/bar.img'
# 	partition:
# 		primary: 4
# 		logical: 1
# 	path: '/baz/qux'
# .then (stream) ->
# 	stream.pipe(fs.createWriteStream('/bar/qux'))
###
exports.read = (definition) ->
	checkImageType(definition.image)
	if _.isString(definition.image)
		fs.openAsync(definition.image, 'r')
		.then (fd) ->
			close = -> fs.closeAsync(fd)
			disk = new filedisk.FileDisk(fd, true)
			read(disk, definition.partition, definition.path)
			.tap (stream) ->
				stream.on('end', close)
				stream.on('error', close)
	else if definition.image instanceof filedisk.Disk
		read(definition.image, definition.partition, definition.path)

write = (disk, partition, path, stream) ->
	driver.interact(disk, partition)
	.then (fat) ->
		stream.pipe(fat.createWriteStream(path))

###*
# @summary Write a stream to a device file
# @function
# @public
#
# @param {Object} definition - device path definition
# @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
# @param {Object} [definition.partition] - partition definition
# @param {String} definition.path - file path
#
# @param {ReadStream} stream - contents stream
# @returns {Promise<WriteStream>}
#
# @example
# imagefs.write
# 	image: '/foo/bar.img'
# 	partition:
# 		primary: 2
# 	path: '/baz/qux'
# , fs.createReadStream('/baz/qux')
###
exports.write = (definition, stream) ->
	checkImageType(definition.image)
	if _.isString(definition.image)
		fs.openAsync(definition.image, 'r+')
		.then (fd) ->
			close = -> fs.closeAsync(fd)
			disk = new filedisk.FileDisk(fd, false, false)
			write(disk, definition.partition, definition.path, stream)
			.tap (writeStream) ->
				writeStream.on('close', close)
				writeStream.on('error', close)
	else if definition.image instanceof filedisk.Disk
		write(definition.image, definition.partition, definition.path, stream)

readFile = (disk, partition, path) ->
	driver.interact(disk, partition)
	.then (fat) ->
		fat.readFileAsync(path, encoding: 'utf8')

###*
# @summary Read a device file
# @function
# @public
#
# @param {Object} definition - device path definition
# @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
# @param {Object} [definition.partition] - partition definition
# @param {String} definition.path - file path
#
# @returns {Promise<String>} file text
#
# @example
# imagefs.readFile
# 	image: '/foo/bar.img'
# 	partition:
# 		primary: 4
# 		logical: 1
# 	path: '/baz/qux'
# .then (contents) ->
# 	console.log(contents)
###
exports.readFile = (definition) ->
	checkImageType(definition.image)
	if _.isString(definition.image)
		Promise.using filedisk.openFile(definition.image, 'r'), (fd) ->
			disk = new filedisk.FileDisk(fd)
			readFile(disk, definition.partition, definition.path)
	else if definition.image instanceof filedisk.Disk
		readFile(definition.image, definition.partition, definition.path)

writeFile = (disk, partition, path, contents) ->
	driver.interact(disk, partition)
	.then (fat) ->
		fat.writeFileAsync(path, contents)

###*
# @summary Write a device file
# @function
# @public
#
# @param {Object} definition - device path definition
# @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
# @param {Object} [definition.partition] - partition definition
# @param {String} definition.path - file path
#
# @param {String} contents - contents string
# @returns {Promise}
#
# @example
# imagefs.writeFile
# 	image: '/foo/bar.img'
# 	partition:
# 		primary: 2
# 	path: '/baz/qux'
# , 'foo bar baz'
###
exports.writeFile = (definition, contents) ->
	checkImageType(definition.image)
	if _.isString(definition.image)
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
# @param {Object} [input.partition] - partition definition
# @param {String} input.path - file path
#
# @param {Object} output - output device path definition
# @param {String} output.image - path to the image
# @param {Object} [output.partition] - partition definition
# @param {String} output.path - file path
#
# @returns {Promise<WriteStream>}
#
# @example
# imagefs.copy
# 	image: '/foo/bar.img'
# 	partition:
# 		primary: 2
# 	path: '/baz/qux'
# ,
# 	image: '/foo/bar.img'
# 	partition:
# 		primary: 4
# 		logical: 1
# 	path: '/baz/hello'
###
exports.copy = (input, output) ->
	exports.read(input).then (stream) ->
		exports.write(output, stream)

###*
# @summary Perform search and replacement in a file
# @function
# @public
#
# @param {Object} definition - device path definition
# @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
# @param {Object} [definition.partition] - partition definition
# @param {String} definition.path - file path
#
# @param {(String|RegExp)} search - search term
# @param {String} replace - replace value
#
# @returns {Promise<WriteStream>}
#
# @example
# imagefs.replace
# 	image: '/foo/bar.img'
# 	partition:
# 		primary: 2
# 	path: '/baz/qux'
# , 'bar', 'baz'
###
exports.replace = (definition, search, replace) ->
	exports.read(definition).then (stream) ->
		replacedStream = stream.pipe(replaceStream(search, replace))
		exports.write(definition, replacedStream)

listDirectory = (disk, partition, path) ->
	driver.interact(disk, partition)
	.then (fat) ->
		fat.readdirAsync(path)
	.filter (file) ->
		return not _.startsWith(file, '.')

###*
# @summary List the contents of a directory
# @function
# @public
#
# @param {Object} definition - device path definition
# @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
# @param {Object} [definition.partition] - partition definition
# @param {String} definition.path - directory path
#
# @returns {Promise<String[]>} list of files in directory
#
# @example
# imagefs.listDirectory
# 	image: '/foo/bar.img'
# 	partition:
# 		primary: 4
# 		logical: 1
# 	path: '/my/directory'
# .then (files) ->
# 	console.log(files)
###
exports.listDirectory = (definition) ->
	checkImageType(definition.image)
	if _.isString(definition.image)
		Promise.using filedisk.openFile(definition.image, 'r+'), (fd) ->
			disk = new filedisk.FileDisk(fd)
			listDirectory(disk, definition.partition, definition.path)
	else if definition.image instanceof filedisk.Disk
		listDirectory(definition.image, definition.partition, definition.path)
