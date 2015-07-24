###
The MIT License

Copyright (c) 2015 Resin.io, Inc. https://resin.io.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
###

###*
# @module imagefs
###

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

		# "touch" the file before writing to it to make sure it exists
		# otherwise, the write operation is ignored and no error is thrown.
		fat.openAsync(definition.path, 'w').then(fat.closeAsync).then ->

			return stream.pipe(fat.createWriteStream(definition.path))

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
