
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
var Promise, SECTOR_SIZE, fatfs, fs, partitioninfo;

partitioninfo = require('partitioninfo');

Promise = require('bluebird');

fs = Promise.promisifyAll(require('fs'));

fatfs = require('fatfs');

SECTOR_SIZE = 512;


/**
 * @summary Get a fatfs driver given a file descriptor
 * @protected
 * @function
 *
 * @param {Object} fd - file descriptor
 * @param {Number} offset - offset of the image
 * @param {Number} size - size of the image
 * @returns {Object} the fatfs driver
 *
 * @example
 * fatDriver = driver.getDriver(fd, 0, 2048)
 */

exports.getDriver = function(fd, offset, size) {
  return {
    sectorSize: SECTOR_SIZE,
    numSectors: size / SECTOR_SIZE,
    readSectors: function(sector, dest, callback) {
      var position;
      position = offset + sector * SECTOR_SIZE;
      return fs.read(fd, dest, 0, dest.length, position, function(error, bytesRead, buffer) {
        return callback(error, buffer);
      });
    },
    writeSectors: function(sector, data, callback) {
      var position;
      position = offset + sector * SECTOR_SIZE;
      return fs.write(fd, data, 0, data.length, position, callback);
    }
  };
};


/**
 * @summary Get a fatfs driver from a file
 * @protected
 * @function
 *
 * @param {String} file - file path
 * @param {Number} offset - offset of the image
 * @param {Number} size - size of the image
 * @returns {Promise<Object>} fatfs filesystem object
 *
 * @todo Test this.
 *
 * @example
 * driver.createDriverFromFile('my/file').then (driver) ->
 * 	console.log(driver)
 */

exports.createDriverFromFile = function(file, offset, size) {
  return fs.openAsync(file, 'r+').then(function(fd) {
    var driver, fat;
    driver = exports.getDriver(fd, offset, size);
    fat = fatfs.createFileSystem(driver);
    return Promise.fromNode(function(callback) {
      fat.on('error', callback);
      return fat.on('ready', function() {
        return callback(null, Promise.promisifyAll(fat));
      });
    });
  });
};


/**
 * @summary Get a fs instance pointing to a FAT partition
 * @protected
 * @function
 *
 * @description
 * If no partition definition is passed, an hddimg partition file is assumed.
 *
 * @param {String} image - image path
 * @param {Object} [definition] - partition definition
 *
 * @returns {Promise<Object>} filesystem object
 *
 * @example
 * driver.interact('foo/bar.img', primary: 1).then (fs) ->
 * 	fs.readdirAsync('/').then (files) ->
 * 		console.log(files)
 */

exports.interact = function(image, definition) {
  return Promise["try"](function() {
    if (definition != null) {
      return partitioninfo.get(image, definition);
    }
    return fs.statAsync(image).get('size').then(function(size) {
      return {
        offset: 0,
        size: size
      };
    });
  }).then(function(information) {
    return exports.createDriverFromFile(image, information.offset, information.size);
  });
};
