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
_ = require('lodash')
ext2fs = Promise.promisifyAll(require('ext2fs'))

SECTOR_SIZE = 512

createFatDriverDisposer = (disk, offset, size) ->
	fatfs = require('fatfs')
	sectorPosition = (sector) -> offset + sector * SECTOR_SIZE
	fat = fatfs.createFileSystem
		sectorSize: SECTOR_SIZE
		numSectors: size / SECTOR_SIZE
		readSectors: (sector, dest, callback) ->
			disk.read(dest, 0, dest.length, sectorPosition(sector))
			.then ({ bytesRead, buffer }) ->
				callback(null, bytesRead, buffer)
			.catch(callback)
		writeSectors: (sector, data, callback) ->
			disk.write(data, 0, data.length, sectorPosition(sector), callback)
			.then ({ bytesWritten, buffer }) ->
				callback(null, bytesWritten, buffer)
			.catch(callback)
	return new Promise (resolve, reject) ->
		fat.on('error', reject)
		fat.on 'ready', ->
			resolve(fat)
	.then (fat) ->
		Promise.resolve(Promise.promisifyAll(fat))
		.disposer ->
			# fatfs doesn't require you to do anything to "umount" the filesystem.
			return

createExtDriverDisposer = (disk, offset, size) ->
	ext2fs.mountAsync(disk, offset: offset)
	.then (fs_) ->
		Promise.resolve(Promise.promisifyAll(fs_))
		.disposer (fs_) ->
			ext2fs.umountAsync(fs_)

###*
# @summary Get a fatfs / node-ext2fs driver from a file
# @protected
# @function
#
# @param {filedisk.Disk} disk - filedisk.Disk instance
# @param {Number} offset - offset of the image
# @param {Number} size - size of the image
# @returns {disposer<Object>} a bluebird diposer of a node fs like interface
#
# @example
# Promise.using openFile('my/file', 'r+'), (fd) ->
#     disk = new filedisk.FileDisk(fd)
#     Promise.using createDriverFromFile(disk), (driver) ->
# 	      console.log(driver)
###
createDriverFromFile = (disk, offset, size, type) ->
	createExtDriverDisposer(disk, offset, size)
	.catch ->
		createFatDriverDisposer(disk, offset, size)
		.catch ->
			throw new Error('Unsupported filesystem.')

###*
# @summary Get a bluebird disposer of an fs instance pointing to a FAT or ext{2,3,4} partition
# @protected
# @function
#
# @description
# If no partition number is passed, a raw partition file is assumed.
#
# @param {filedisk.Disk} disk - filedisk.Disk instance
# @param {Number} [partition] - partition number
#
# @returns {disposer<Object>} filesystem object
#
# @example
# Promise.using filedisk.openFile('foo/bar.img', 'r+'), (fd) ->
#     disk = new filedisk.FileDisk(fd)
#     Promise.using driver.interact(disk, 1), (fs) ->
# 	      fs.readdirAsync('/')
#     .then (files) ->
#         console.log(files)
###
exports.interact = (disk, partition) ->
	disk = Promise.promisifyAll(disk)
	Promise.try ->
		if _.isUndefined(partition)
			# Handle raw partition files
			Promise.props
				offset: 0
				size: disk.getCapacity()
		else
			partitioninfo.get(disk, partition)
	.then ({ offset, size, type }) ->
		createDriverFromFile(disk, offset, size, type)
