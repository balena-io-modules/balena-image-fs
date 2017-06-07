
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
var Promise, checkImageType, driver, filedisk, fs, listDirectory, read, readFile, replaceStream, write, writeFile, _;

Promise = require('bluebird');

_ = require('lodash');

filedisk = require('file-disk');

fs = Promise.promisifyAll(require('fs'));

replaceStream = require('replacestream');

driver = require('./driver');

checkImageType = function(image) {
  if (!(_.isString(image) || image instanceof filedisk.Disk)) {
    throw new Error('image must be a String (file path) or a filedisk.Disk instance');
  }
};


/**
 * @summary Get a device file readable stream
 * @function
 * @public
 *
 * @param {Object} definition - device path definition
 * @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
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
  checkImageType(definition.image);
  if (_.isString(definition.image)) {
    return fs.openAsync(definition.image, 'r').then(function(fd) {
      var close, disk;
      close = function() {
        return fs.closeAsync(fd);
      };
      disk = new filedisk.FileDisk(fd, true);
      return read(disk, definition.partition, definition.path).tap(function(stream) {
        stream.on('end', close);
        return stream.on('error', close);
      });
    });
  } else if (definition.image instanceof filedisk.Disk) {
    return read(definition.image, definition.partition, definition.path);
  }
};

read = function(disk, partition, path) {
  return driver.interact(disk, partition).then(function(fat) {
    return fat.createReadStream(path);
  });
};


/**
 * @summary Write a stream to a device file
 * @function
 * @public
 *
 * @param {Object} definition - device path definition
 * @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
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
  checkImageType(definition.image);
  if (_.isString(definition.image)) {
    return fs.openAsync(definition.image, 'r+').then(function(fd) {
      var close, disk;
      close = function() {
        return fs.closeAsync(fd);
      };
      disk = new filedisk.FileDisk(fd, false, false);
      return write(disk, definition.partition, definition.path, stream).tap(function(writeStream) {
        writeStream.on('close', close);
        return writeStream.on('error', close);
      });
    });
  } else if (definition.image instanceof filedisk.Disk) {
    return write(definition.image, definition.partition, definition.path, stream);
  }
};

write = function(disk, partition, path, stream) {
  return driver.interact(disk, partition).then(function(fat) {
    return stream.pipe(fat.createWriteStream(path));
  });
};


/**
 * @summary Read a device file
 * @function
 * @public
 *
 * @param {Object} definition - device path definition
 * @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
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
  checkImageType(definition.image);
  if (_.isString(definition.image)) {
    return Promise.using(filedisk.openFile(definition.image, 'r'), function(fd) {
      var disk;
      disk = new filedisk.FileDisk(fd);
      return readFile(disk, definition.partition, definition.path);
    });
  } else if (definition.image instanceof filedisk.Disk) {
    return readFile(definition.image, definition.partition, definition.path);
  }
};

readFile = function(disk, partition, path) {
  return driver.interact(disk, partition).then(function(fat) {
    return fat.readFileAsync(path, {
      encoding: 'utf8'
    });
  });
};


/**
 * @summary Write a device file
 * @function
 * @public
 *
 * @param {Object} definition - device path definition
 * @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
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
  checkImageType(definition.image);
  if (_.isString(definition.image)) {
    return Promise.using(filedisk.openFile(definition.image, 'r+'), function(fd) {
      var disk;
      disk = new filedisk.FileDisk(fd);
      return writeFile(disk, definition.partition, definition.path, contents);
    });
  } else if (definition.image instanceof filedisk.Disk) {
    return writeFile(definition.image, definition.partition, definition.path, contents);
  }
};

writeFile = function(disk, partition, path, contents) {
  return driver.interact(disk, partition).then(function(fat) {
    return fat.writeFileAsync(path, contents);
  });
};


/**
 * @summary Copy a device file
 * @function
 * @public
 *
 * @param {Object} input - input device path definition
 * @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
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
 * @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
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
 * @param {String|filedisk.Disk} definition.image - path to the image or filedisk.Disk instance
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
  checkImageType(definition.image);
  if (_.isString(definition.image)) {
    return Promise.using(filedisk.openFile(definition.image, 'r+'), function(fd) {
      var disk;
      disk = new filedisk.FileDisk(fd);
      return listDirectory(disk, definition.partition, definition.path);
    });
  } else if (definition.image instanceof filedisk.Disk) {
    return listDirectory(definition.image, definition.partition, definition.path);
  }
};

listDirectory = function(disk, partition, path) {
  return driver.interact(disk, partition).then(function(fat) {
    return fat.readdirAsync(path);
  }).filter(function(file) {
    return !_.startsWith(file, '.');
  });
};
