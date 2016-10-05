
/*
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
 */

/**
 * @module imagefs
 */
var Promise, driver, replaceStream, _;

_ = require('lodash');

replaceStream = require('replacestream');

Promise = require('bluebird');

driver = require('./driver');


/**
 * @summary Get a device file readable stream
 * @function
 * @public
 *
 * @param {Object} definition - device path definition
 * @param {String} definition.image - path to the image
 * @param {Object} [definition.partition] - partition definition
 * @param {String} definition.path - file path
 *
 * @returns {Promise<ReadStream>} file stream
 *
 * @example
 * imagefs.read
 * 	image: '/foo/bar.img'
 * 	partition:
 * 		primary: 4
 * 		logical: 1
 * 	path: '/baz/qux'
 * .then (stream) ->
 * 	stream.pipe(fs.createWriteStream('/bar/qux'))
 */

exports.read = function(definition) {
  return driver.interact(definition.image, definition.partition).then(function(fat) {
    return fat.createReadStream(definition.path).on('end', fat.closeDriver);
  });
};


/**
 * @summary Write a stream to a device file
 * @function
 * @public
 *
 * @param {Object} definition - device path definition
 * @param {String} definition.image - path to the image
 * @param {Object} [definition.partition] - partition definition
 * @param {String} definition.path - file path
 *
 * @param {ReadStream} stream - contents stream
 * @returns {Promise<WriteStream>}
 *
 * @example
 * imagefs.write
 * 	image: '/foo/bar.img'
 * 	partition:
 * 		primary: 2
 * 	path: '/baz/qux'
 * , fs.createReadStream('/baz/qux')
 */

exports.write = function(definition, stream) {
  return driver.interact(definition.image, definition.partition).then(function(fat) {
    return stream.pipe(fat.createWriteStream(definition.path)).on('close', fat.closeDriver);
  });
};


/**
 * @summary Read a device file
 * @function
 * @public
 *
 * @param {Object} definition - device path definition
 * @param {String} definition.image - path to the image
 * @param {Object} [definition.partition] - partition definition
 * @param {String} definition.path - file path
 *
 * @returns {Promise<String>} file text
 *
 * @example
 * imagefs.readFile
 * 	image: '/foo/bar.img'
 * 	partition:
 * 		primary: 4
 * 		logical: 1
 * 	path: '/baz/qux'
 * .then (contents) ->
 * 	console.log(contents)
 */

exports.readFile = function(definition) {
  return driver.interact(definition.image, definition.partition).then(function(fat) {
    return fat.readFileAsync(definition.path, {
      encoding: 'utf8'
    }).tap(fat.closeDriver);
  });
};


/**
 * @summary Write a device file
 * @function
 * @public
 *
 * @param {Object} definition - device path definition
 * @param {String} definition.image - path to the image
 * @param {Object} [definition.partition] - partition definition
 * @param {String} definition.path - file path
 *
 * @param {String} contents - contents string
 * @returns {Promise}
 *
 * @example
 * imagefs.writeFile
 * 	image: '/foo/bar.img'
 * 	partition:
 * 		primary: 2
 * 	path: '/baz/qux'
 * , 'foo bar baz'
 */

exports.writeFile = function(definition, contents) {
  return driver.interact(definition.image, definition.partition).then(function(fat) {
    return fat.writeFileAsync(definition.path, contents).tap(fat.closeDriver);
  });
};


/**
 * @summary Copy a device file
 * @function
 * @public
 *
 * @param {Object} input - input device path definition
 * @param {String} input.image - path to the image
 * @param {Object} [input.partition] - partition definition
 * @param {String} input.path - file path
 *
 * @param {Object} output - output device path definition
 * @param {String} output.image - path to the image
 * @param {Object} [output.partition] - partition definition
 * @param {String} output.path - file path
 *
 * @returns {Promise<WriteStream>}
 *
 * @example
 * imagefs.copy
 * 	image: '/foo/bar.img'
 * 	partition:
 * 		primary: 2
 * 	path: '/baz/qux'
 * ,
 * 	image: '/foo/bar.img'
 * 	partition:
 * 		primary: 4
 * 		logical: 1
 * 	path: '/baz/hello'
 */

exports.copy = function(input, output) {
  return exports.read(input).then(function(stream) {
    return exports.write(output, stream);
  });
};


/**
 * @summary Perform search and replacement in a file
 * @function
 * @public
 *
 * @param {Object} definition - device path definition
 * @param {String} definition.image - path to the image
 * @param {Object} [definition.partition] - partition definition
 * @param {String} definition.path - file path
 *
 * @param {(String|RegExp)} search - search term
 * @param {String} replace - replace value
 *
 * @returns {Promise<WriteStream>}
 *
 * @example
 * imagefs.replace
 * 	image: '/foo/bar.img'
 * 	partition:
 * 		primary: 2
 * 	path: '/baz/qux'
 * , 'bar', 'baz'
 */

exports.replace = function(definition, search, replace) {
  return exports.read(definition).then(function(stream) {
    var replacedStream;
    replacedStream = stream.pipe(replaceStream(search, replace));
    return exports.write(definition, replacedStream);
  });
};


/**
 * @summary List the contents of a directory
 * @function
 * @public
 *
 * @param {Object} definition - device path definition
 * @param {String} definition.image - path to the image
 * @param {Object} [definition.partition] - partition definition
 * @param {String} definition.path - directory path
 *
 * @returns {Promise<String[]>} list of files in directory
 *
 * @example
 * imagefs.listDirectory
 * 	image: '/foo/bar.img'
 * 	partition:
 * 		primary: 4
 * 		logical: 1
 * 	path: '/my/directory'
 * .then (files) ->
 * 	console.log(files)
 */

exports.listDirectory = function(definition) {
  return driver.interact(definition.image, definition.partition).then(function(fat) {
    return fat.readdirAsync(definition.path).filter(function(file) {
      return !_.startsWith(file, '.');
    }).tap(fat.closeDriver);
  });
};
