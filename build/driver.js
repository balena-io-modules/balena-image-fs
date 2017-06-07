
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
var Promise, SECTOR_SIZE, createDriverFromFile, fatfs, fs, getDriver, partitioninfo;

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
 * @param {filedisk.Disk} disk - filedisk.Disk instance
 * @param {Number} offset - offset of the image
 * @param {Number} size - size of the image
 * @returns {Object} the fatfs driver
 *
 * @example
 * disk = new filedisk.FileDisk(fd)
 * fatDriver = getDriver(disk, 0, 2048)
 */

getDriver = function(disk, offset, size) {
  var sectorPosition;
  sectorPosition = function(sector) {
    return offset + sector * SECTOR_SIZE;
  };
  return {
    sectorSize: SECTOR_SIZE,
    numSectors: size / SECTOR_SIZE,
    readSectors: function(sector, dest, callback) {
      return disk.read(dest, 0, dest.length, sectorPosition(sector), callback);
    },
    writeSectors: function(sector, data, callback) {
      return disk.write(data, 0, data.length, sectorPosition(sector), callback);
    }
  };
};


/**
 * @summary Get a fatfs driver from a file
 * @protected
 * @function
 *
 * @param {filedisk.Disk} disk - filedisk.Disk instance
 * @param {Number} offset - offset of the image
 * @param {Number} size - size of the image
 * @returns {Promise<Object>} fatfs filesystem object
 *
 * @todo Test this.
 *
 * @example
 * Promise.using openFile('my/file', 'r+'), (fd) ->
 *     disk = new filedisk.FileDisk(fd)
 *     createDriverFromFile(disk)
 *     .then (driver) ->
 * 	      console.log(driver)
 */

createDriverFromFile = function(disk, offset, size) {
  var driver, fat;
  driver = getDriver(disk, offset, size);
  fat = fatfs.createFileSystem(driver);
  return Promise.fromNode(function(callback) {
    fat.on('error', callback);
    return fat.on('ready', function() {
      return callback(null, Promise.promisifyAll(fat));
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
 * @param {filedisk.Disk} disk - filedisk.Disk instance
 * @param {Object} [definition] - partition definition
 *
 * @returns {Promise<Object>} filesystem object
 *
 * @example
 * Promise.using filedisk.openFile('foo/bar.img', 'r+'), (fd) ->
 *     disk = new filedisk.FileDisk(fd)
 *     driver.interact(disk, primary: 1)
 *     .then (fs) ->
 * 	      fs.readdirAsync('/')
 *         .then (files) ->
 * 		      console.log(files)
 */

exports.interact = function(disk, definition) {
  disk = Promise.promisifyAll(disk);
  return Promise["try"](function() {
    if (definition) {
      return partitioninfo.get(disk, definition);
    } else {
      return disk.getCapacityAsync().then(function(size) {
        return {
          offset: 0,
          size: size
        };
      });
    }
  }).then(function(information) {
    return createDriverFromFile(disk, information.offset, information.size);
  });
};
