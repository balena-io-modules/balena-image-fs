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

filedisk = require('file-disk')

driver = require('./driver')

###*
# @summary Run a function with a node fs like interface for a partition
#
# @param {String|filedisk.Disk} disk - path to the image or filedisk.Disk instance
# @param {Number|undefined} partition - partition number, undefined for images with no partition table
# @param {function} fn - funciton to run
#
# @example
#
# imagefs.interact '/foo/bar.img', 5, (fs) ->
#   fs.readFileAsync('/bar/qux')
#   .then (contents) ->
#     console.log(contents)
###
exports.interact = (disk, partition, fn) ->
	if typeof disk == 'string'
		filedisk.withOpenFile disk, 'r+', (handle) ->
			disk = new filedisk.FileDisk(handle)
			driver.interact(disk, partition, fn)
	else if disk instanceof filedisk.Disk
		driver.interact(disk, partition, fn)
	else
		throw new Error('image must be a String (file path) or a filedisk.Disk instance')
