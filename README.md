resin-image-fs
--------------

[![npm version](https://badge.fury.io/js/resin-image-fs.svg)](http://badge.fury.io/js/resin-image-fs)
[![dependencies](https://david-dm.org/resin-io/resin-image-fs.png)](https://david-dm.org/resin-io/resin-image-fs.png)
[![Build Status](https://travis-ci.org/resin-io/resin-image-fs.svg?branch=master)](https://travis-ci.org/resin-io/resin-image-fs)
[![Build status](https://ci.appveyor.com/api/projects/status/86bot1jaepcg5xlv?svg=true)](https://ci.appveyor.com/project/resin-io/resin-image-fs)

Join our online chat at [![Gitter chat](https://badges.gitter.im/resin-io/chat.png)](https://gitter.im/resin-io/chat)

Resin.io image filesystem manipulation utilities.

Role
----

The intention of this module is to provide low level utilities to Resin.io operating system data partitions.

**THIS MODULE IS LOW LEVEL AND IS NOT MEANT TO BE USED BY END USERS DIRECTLY**.

Installation
------------

Install `resin-image-fs` by running:

```sh
$ npm install --save resin-image-fs
```

Documentation
-------------


* [imagefs](#module_imagefs)
    * [.interact(disk, partition)](#module_imagefs.interact) ⇒ <code>bluebird.disposer.&lt;fs&gt;</code>
    * [.read(definition)](#module_imagefs.read) ⇒ <code>bluebird.disposer.&lt;ReadStream&gt;</code>
    * [.write(definition, stream)](#module_imagefs.write) ⇒ <code>Promise</code>
    * [.readFile(definition)](#module_imagefs.readFile) ⇒ <code>Promise.&lt;String&gt;</code>
    * [.writeFile(definition, contents)](#module_imagefs.writeFile) ⇒ <code>Promise</code>
    * [.copy(input, output)](#module_imagefs.copy) ⇒ <code>Promise</code>
    * [.replace(definition, search, replace)](#module_imagefs.replace) ⇒ <code>Promise</code>
    * [.listDirectory(definition)](#module_imagefs.listDirectory) ⇒ <code>Promise.&lt;Array.&lt;String&gt;&gt;</code>

<a name="module_imagefs.interact"></a>

### imagefs.interact(disk, partition) ⇒ <code>bluebird.disposer.&lt;fs&gt;</code>
**Kind**: static method of [<code>imagefs</code>](#module_imagefs)  
**Summary**: Get a bluebird.disposer of a node fs like interface for a partition  
**Returns**: <code>bluebird.disposer.&lt;fs&gt;</code> - node fs like interface  
**Access**: public  

| Param | Type | Description |
| --- | --- | --- |
| disk | <code>String</code> \| <code>filedisk.Disk</code> | path to the image or filedisk.Disk instance |
| partition | <code>Number</code> | partition number |

**Example**  
```js
Promise.using imagefs.interact('/foo/bar.img', 5), (fs) ->
  fs.readFileAsync('/bar/qux')
  .then (contents) ->
    console.log(contents)
```
<a name="module_imagefs.read"></a>

### imagefs.read(definition) ⇒ <code>bluebird.disposer.&lt;ReadStream&gt;</code>
**Kind**: static method of [<code>imagefs</code>](#module_imagefs)  
**Summary**: Get a device file readable stream  
**Returns**: <code>bluebird.disposer.&lt;ReadStream&gt;</code> - file stream  
**Access**: public  

| Param | Type | Description |
| --- | --- | --- |
| definition | <code>Object</code> | device path definition |
| definition.image | <code>String</code> \| <code>filedisk.Disk</code> | path to the image or filedisk.Disk instance |
| [definition.partition] | <code>Number</code> | partition number |
| definition.path | <code>String</code> | file path |

**Example**  
```js
disposer = imagefs.read
	image: '/foo/bar.img'
	partition: 5
	path: '/baz/qux'

Promise.using disposer, (stream) ->
  out = fs.createWriteStream('/bar/qux')
  stream.pipe(out)
  utils.waitStream(out)
```
<a name="module_imagefs.write"></a>

### imagefs.write(definition, stream) ⇒ <code>Promise</code>
**Kind**: static method of [<code>imagefs</code>](#module_imagefs)  
**Summary**: Write a stream to a device file  
**Access**: public  

| Param | Type | Description |
| --- | --- | --- |
| definition | <code>Object</code> | device path definition |
| definition.image | <code>String</code> \| <code>filedisk.Disk</code> | path to the image or filedisk.Disk instance |
| [definition.partition] | <code>Number</code> | partition number |
| definition.path | <code>String</code> | file path |
| stream | <code>ReadStream</code> | contents stream |

**Example**  
```js
imagefs.write
	image: '/foo/bar.img'
	partition: 2
	path: '/baz/qux'
, fs.createReadStream('/baz/qux')
```
<a name="module_imagefs.readFile"></a>

### imagefs.readFile(definition) ⇒ <code>Promise.&lt;String&gt;</code>
**Kind**: static method of [<code>imagefs</code>](#module_imagefs)  
**Summary**: Read a device file  
**Returns**: <code>Promise.&lt;String&gt;</code> - file text  
**Access**: public  

| Param | Type | Description |
| --- | --- | --- |
| definition | <code>Object</code> | device path definition |
| definition.image | <code>String</code> \| <code>filedisk.Disk</code> | path to the image or filedisk.Disk instance |
| [definition.partition] | <code>Number</code> | partition number |
| definition.path | <code>String</code> | file path |

**Example**  
```js
imagefs.readFile
	image: '/foo/bar.img'
	partition: 5
	path: '/baz/qux'
.then (contents) ->
	console.log(contents)
```
<a name="module_imagefs.writeFile"></a>

### imagefs.writeFile(definition, contents) ⇒ <code>Promise</code>
**Kind**: static method of [<code>imagefs</code>](#module_imagefs)  
**Summary**: Write a device file  
**Access**: public  

| Param | Type | Description |
| --- | --- | --- |
| definition | <code>Object</code> | device path definition |
| definition.image | <code>String</code> \| <code>filedisk.Disk</code> | path to the image or filedisk.Disk instance |
| [definition.partition] | <code>Number</code> | partition number |
| definition.path | <code>String</code> | file path |
| contents | <code>String</code> | contents string |

**Example**  
```js
imagefs.writeFile
	image: '/foo/bar.img'
	partition: 2
	path: '/baz/qux'
, 'foo bar baz'
```
<a name="module_imagefs.copy"></a>

### imagefs.copy(input, output) ⇒ <code>Promise</code>
**Kind**: static method of [<code>imagefs</code>](#module_imagefs)  
**Summary**: Copy a device file  
**Access**: public  

| Param | Type | Description |
| --- | --- | --- |
| input | <code>Object</code> | input device path definition |
| definition.image | <code>String</code> \| <code>filedisk.Disk</code> | path to the image or filedisk.Disk instance |
| [input.partition] | <code>Number</code> | partition number |
| input.path | <code>String</code> | file path |
| output | <code>Object</code> | output device path definition |
| output.image | <code>String</code> | path to the image |
| [output.partition] | <code>Number</code> | partition number |
| output.path | <code>String</code> | file path |

**Example**  
```js
imagefs.copy
	image: '/foo/bar.img'
	partition: 2
	path: '/baz/qux'
,
	image: '/foo/bar.img'
	partition: 5
	path: '/baz/hello'
```
<a name="module_imagefs.replace"></a>

### imagefs.replace(definition, search, replace) ⇒ <code>Promise</code>
**Kind**: static method of [<code>imagefs</code>](#module_imagefs)  
**Summary**: Perform search and replacement in a file  
**Access**: public  

| Param | Type | Description |
| --- | --- | --- |
| definition | <code>Object</code> | device path definition |
| definition.image | <code>String</code> \| <code>filedisk.Disk</code> | path to the image or filedisk.Disk instance |
| [definition.partition] | <code>Number</code> | partition number |
| definition.path | <code>String</code> | file path |
| search | <code>String</code> \| <code>RegExp</code> | search term |
| replace | <code>String</code> | replace value |

**Example**  
```js
imagefs.replace
	image: '/foo/bar.img'
	partition: 2
	path: '/baz/qux'
, 'bar', 'baz'
```
<a name="module_imagefs.listDirectory"></a>

### imagefs.listDirectory(definition) ⇒ <code>Promise.&lt;Array.&lt;String&gt;&gt;</code>
**Kind**: static method of [<code>imagefs</code>](#module_imagefs)  
**Summary**: List the contents of a directory  
**Returns**: <code>Promise.&lt;Array.&lt;String&gt;&gt;</code> - list of files in directory  
**Access**: public  

| Param | Type | Description |
| --- | --- | --- |
| definition | <code>Object</code> | device path definition |
| definition.image | <code>String</code> \| <code>filedisk.Disk</code> | path to the image or filedisk.Disk instance |
| [definition.partition] | <code>Number</code> | partition number |
| definition.path | <code>String</code> | directory path |

**Example**  
```js
imagefs.listDirectory
	image: '/foo/bar.img'
	partition: 5
	path: '/my/directory'
.then (files) ->
	console.log(files)
```

Support
-------

If you're having any problem, please [raise an issue](https://github.com/resin-io/resin-image-fs/issues/new) on GitHub and the Resin.io team will be happy to help.

Tests
-----

Run the test suite by doing:

```sh
$ npm test
```

Contribute
----------

- Issue Tracker: [github.com/resin-io/resin-image-fs/issues](https://github.com/resin-io/resin-image-fs/issues)
- Source Code: [github.com/resin-io/resin-image-fs](https://github.com/resin-io/resin-image-fs)

Before submitting a PR, please make sure that you include tests, and that [coffeelint](http://www.coffeelint.org/) runs without any warning:

```sh
$ npm test
```

License
-------

The project is licensed under the Apache 2.0 license.
