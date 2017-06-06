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
fs = Promise.promisifyAll(require('fs'))
fatfs = require('fatfs')
ext2fs = Promise.promisifyAll(require('ext2fs'))
magic = Promise.promisifyAll(require('mmmagic'))

SECTOR_SIZE = 512

MAGIC_OPTS = (
	magic.MAGIC_NO_CHECK_TAR |
	magic.MAGIC_NO_CHECK_ENCODING |
	magic.MAGIC_NO_CHECK_TOKENS |
	magic.MAGIC_NO_CHECK_CDF |
	magic.MAGIC_NO_CHECK_TEXT |
	magic.MAGIC_NO_CHECK_ELF |
	magic.MAGIC_NO_CHECK_APPTYPE
)
DETECTOR = new magic.Magic(MAGIC_OPTS)

KNOWN_FILESYSTEMS =
	'node-ext2fs': [ 'ext2', 'ext3', 'ext4' ]
	'fatfs': [ 'FAT' ]

detectDriver = (mime) ->
	for own driver, filesystems of KNOWN_FILESYSTEMS
		for filesystem in filesystems
			if mime.indexOf(filesystem) != -1
				return driver

detectFS = (disk, offset, size) ->
	disk = Promise.promisifyAll(disk, multiArgs: true)
	size = Math.min(size, 2048)
	buf = Buffer.allocUnsafe(size)
	disk.readAsync(buf, 0, size, offset)
	.then ->
		DETECTOR.detectAsync(buf)
	.then (mime) ->
		detectDriver(mime)

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
createDriverFromFile = (disk, offset, size) ->
	detectFS(disk, offset, size)
	.then (driver) ->
		if driver == 'fatfs'
			sectorPosition = (sector) -> offset + sector * SECTOR_SIZE
			fat = fatfs.createFileSystem
				sectorSize: SECTOR_SIZE
				numSectors: size / SECTOR_SIZE
				readSectors: (sector, dest, callback) ->
					disk.read(dest, 0, dest.length, sectorPosition(sector), callback)
				writeSectors: (sector, data, callback) ->
					disk.write(data, 0, data.length, sectorPosition(sector), callback)
			return Promise.fromNode (callback) ->
				fat.on('error', callback)
				fat.on 'ready', ->
					callback(null, Promise.promisifyAll(fat))
			.disposer ->
				return
		else if driver == 'node-ext2fs'
			ext2fs.mountAsync(disk, offset: offset)
			.then (fs_) ->
				Promise.promisifyAll(fs_)
			.disposer (fs_) ->
				ext2fs.umountAsync(fs_)
		else
			throw new Error('Unsupported filesystem.')

###*
# @summary Get a bluebird disposer of an fs instance pointing to a FAT or ext{2,3,4} partition
# @protected
# @function
#
# @description
# If no partition definition is passed, an hddimg partition file is assumed.
#
# @param {filedisk.Disk} disk - filedisk.Disk instance
# @param {Object} [definition] - partition definition
#
# @returns {disposer<Object>} filesystem object
#
# @example
# Promise.using filedisk.openFile('foo/bar.img', 'r+'), (fd) ->
#     disk = new filedisk.FileDisk(fd)
#     Promise.using driver.interact(disk, primary: 1), (fs) ->
# 	      fs.readdirAsync('/')
#     .then (files) ->
#         console.log(files)
###
exports.interact = (disk, definition) ->
	disk = Promise.promisifyAll(disk)
	Promise.try ->
		if definition
			partitioninfo.get(disk, definition)
		else
			# Handle partition files (*.hddimg)
			disk.getCapacityAsync()
			.then (size) ->
				{ offset: 0, size: size }
	.then (information) ->
		createDriverFromFile(disk, information.offset, information.size)
