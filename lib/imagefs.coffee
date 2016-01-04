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

replaceStream = require('replacestream')
driver = require('./driver')

###*
# @summary Read a device file
# @function
# @public
#
# @param {Object} definition - device path definition
# @param {String} definition.image - path to the image
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
	driver.interact(definition.image, definition.partition).then (fat) ->
		return fat.createReadStream(definition.path)
			.on('end', fat.closeDriver)

###*
# @summary Write to a device file
# @function
# @public
#
# @param {Object} definition - device path definition
# @param {String} definition.image - path to the image
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
	driver.interact(definition.image, definition.partition).then (fat) ->
		return stream.pipe(fat.createWriteStream(definition.path))
			.on('close', fat.closeDriver)

###*
# @summary Copy a device file
# @function
# @public
#
# @param {Object} input - input device path definition
# @param {String} input.image - path to the image
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
# @param {String} definition.image - path to the image
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
