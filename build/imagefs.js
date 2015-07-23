
/*
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
 */

/**
 * @module imagefs
 */
var devicePath, driver;

devicePath = require('resin-device-path');

driver = require('./driver');


/**
 * @summary Read a device file
 * @function
 * @public
 *
 * @param {String} definition - device path definition
 * @returns {Promise<ReadStream>} file stream
 *
 * @example
 * imagefs.read('/foo/bar.img(4:1):/baz/qux').then (stream) ->
 *		stream.pipe(fs.createWriteStream('/bar/qux'))
 */

exports.read = function(definition) {
  var pathDefinition;
  pathDefinition = devicePath.parsePath(definition);
  return driver.interact(pathDefinition.input.path, pathDefinition.partition).then(function(fat) {
    return fat.createReadStream(pathDefinition.file);
  });
};


/**
 * @summary Write to a device file
 * @function
 * @public
 *
 * @param {String} definition - device path definition
 * @param {ReadStream} stream - contents stream
 * @returns {Promise}
 *
 * @example
 * imagefs.write('/foo/bar.img(2):/baz/qux', fs.createReadStream('/baz/qux'))
 */

exports.write = function(definition, stream) {
  var pathDefinition;
  pathDefinition = devicePath.parsePath(definition);
  return driver.interact(pathDefinition.input.path, pathDefinition.partition).then(function(fat) {
    return fat.openAsync(pathDefinition.file, 'w').then(fat.closeAsync).then(function() {
      return stream.pipe(fat.createWriteStream(pathDefinition.file));
    });
  });
};


/**
 * @summary Copy a device file
 * @function
 * @public
 *
 * @param {String} input - input device type definition
 * @param {String} output - output device type definition
 *
 * @returns {Promise}
 *
 * @example
 * imagefs.copy('/foo/bar.img(2):/baz/qux', '/foo/bar.img(4:1):/baz/hello')
 */

exports.copy = function(input, output) {
  return exports.read(input).then(function(stream) {
    return exports.write(output, stream);
  });
};
