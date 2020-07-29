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
ext2fs = require('ext2fs')
fatfs = require('fatfs')
util = require('util')

class MountError extends Error
	name: 'MountError'
	constructor: (e) ->
		super(e.message)

SECTOR_SIZE = 512

createFatDriverDisposer = (disk, offset, size, fn) ->
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
		fat.on 'error', (e) ->
			reject(new MountError(e))
		fat.on 'ready', ->
			resolve(fat)
	.then (fat) ->
		fn(fat)

mountAsync = util.promisify(ext2fs.mount)
umountAsync = util.promisify(ext2fs.umount)

createExtDriverDisposer = (disk, offset, size, fn) ->
	mountAsync(disk, offset: offset)
	.catch (e) ->
		throw (new MountError(e))
	.then (fs_) ->
		fn(fs_)
		.finally ->
			umountAsync(fs_)

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
createDriverFromFile = (disk, offset, size, fn) ->
	createExtDriverDisposer(disk, offset, size, fn)
	.catch (e) ->
		if !(e instanceof MountError)
			throw e
		createFatDriverDisposer(disk, offset, size, fn)
		.catch (e) ->
			if !(e instanceof MountError)
				throw e
			throw new Error('Unsupported filesystem.')

getPartition = (disk, partition) ->
	if partition == undefined
		disk.getCapacity()
		.then (size) ->
			{ offset: 0, size }
	else
		partitioninfo.get(disk, partition)

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
exports.interact = (disk, partition, fn) ->
	getPartition(disk, partition)
	.then ({ offset, size }) ->
		createDriverFromFile(disk, offset, size, fn)
