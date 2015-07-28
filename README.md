resin-image-fs
--------------

[![npm version](https://badge.fury.io/js/resin-image-fs.svg)](http://badge.fury.io/js/resin-image-fs)
[![dependencies](https://david-dm.org/resin-io/resin-image-fs.png)](https://david-dm.org/resin-io/resin-image-fs.png)
[![Build Status](https://travis-ci.org/resin-io/resin-image-fs.svg?branch=master)](https://travis-ci.org/resin-io/resin-image-fs)
[![Build status](https://ci.appveyor.com/api/projects/status/86bot1jaepcg5xlv?svg=true)](https://ci.appveyor.com/project/jviotti/resin-image-fs)

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
  * [.read(definition)](#module_imagefs.read) ⇒ <code>Promise.&lt;ReadStream&gt;</code>
  * [.write(definition, stream)](#module_imagefs.write) ⇒ <code>Promise.&lt;WriteStream&gt;</code>
  * [.copy(input, output)](#module_imagefs.copy) ⇒ <code>Promise.&lt;WriteStream&gt;</code>
  * [.replace(definition, search, replace)](#module_imagefs.replace) ⇒ <code>Promise.&lt;WriteStream&gt;</code>

<a name="module_imagefs.read"></a>
### imagefs.read(definition) ⇒ <code>Promise.&lt;ReadStream&gt;</code>
**Kind**: static method of <code>[imagefs](#module_imagefs)</code>  
**Summary**: Read a device file  
**Returns**: <code>Promise.&lt;ReadStream&gt;</code> - file stream  
**Access:** public  

| Param | Type | Description |
| --- | --- | --- |
| definition | <code>Object</code> | device path definition |
| definition.image | <code>String</code> | path to the image |
| [definition.partition] | <code>Object</code> | partition definition |
| definition.path | <code>String</code> | file path |

**Example**  
```js
imagefs.read
	image: '/foo/bar.img'
	partition:
		primary: 4
		logical: 1
	path: '/baz/qux'
.then (stream) ->
	stream.pipe(fs.createWriteStream('/bar/qux'))
```
<a name="module_imagefs.write"></a>
### imagefs.write(definition, stream) ⇒ <code>Promise.&lt;WriteStream&gt;</code>
**Kind**: static method of <code>[imagefs](#module_imagefs)</code>  
**Summary**: Write to a device file  
**Access:** public  

| Param | Type | Description |
| --- | --- | --- |
| definition | <code>Object</code> | device path definition |
| definition.image | <code>String</code> | path to the image |
| [definition.partition] | <code>Object</code> | partition definition |
| definition.path | <code>String</code> | file path |
| stream | <code>ReadStream</code> | contents stream |

**Example**  
```js
imagefs.write
	image: '/foo/bar.img'
	partition:
		primary: 2
	path: '/baz/qux'
, fs.createReadStream('/baz/qux')
```
<a name="module_imagefs.copy"></a>
### imagefs.copy(input, output) ⇒ <code>Promise.&lt;WriteStream&gt;</code>
**Kind**: static method of <code>[imagefs](#module_imagefs)</code>  
**Summary**: Copy a device file  
**Access:** public  

| Param | Type | Description |
| --- | --- | --- |
| input | <code>Object</code> | input device path definition |
| input.image | <code>String</code> | path to the image |
| [input.partition] | <code>Object</code> | partition definition |
| input.path | <code>String</code> | file path |
| output | <code>Object</code> | output device path definition |
| output.image | <code>String</code> | path to the image |
| [output.partition] | <code>Object</code> | partition definition |
| output.path | <code>String</code> | file path |

**Example**  
```js
imagefs.copy
	image: '/foo/bar.img'
	partition:
		primary: 2
	path: '/baz/qux'
,
	image: '/foo/bar.img'
	partition:
		primary: 4
		logical: 1
	path: '/baz/hello'
```
<a name="module_imagefs.replace"></a>
### imagefs.replace(definition, search, replace) ⇒ <code>Promise.&lt;WriteStream&gt;</code>
**Kind**: static method of <code>[imagefs](#module_imagefs)</code>  
**Summary**: Perform search and replacement in a file  
**Access:** public  

| Param | Type | Description |
| --- | --- | --- |
| definition | <code>Object</code> | device path definition |
| definition.image | <code>String</code> | path to the image |
| [definition.partition] | <code>Object</code> | partition definition |
| definition.path | <code>String</code> | file path |
| search | <code>String</code> &#124; <code>RegExp</code> | search term |
| replace | <code>String</code> | replace value |

**Example**  
```js
imagefs.replace
	image: '/foo/bar.img'
	partition:
		primary: 2
	path: '/baz/qux'
, 'bar', 'baz'
```

Support
-------

If you're having any problem, please [raise an issue](https://github.com/resin-io/resin-image-fs/issues/new) on GitHub and the Resin.io team will be happy to help.

Tests
-----

Run the test suite by doing:

```sh
$ gulp test
```

Contribute
----------

- Issue Tracker: [github.com/resin-io/resin-image-fs/issues](https://github.com/resin-io/resin-image-fs/issues)
- Source Code: [github.com/resin-io/resin-image-fs](https://github.com/resin-io/resin-image-fs)

Before submitting a PR, please make sure that you include tests, and that [coffeelint](http://www.coffeelint.org/) runs without any warning:

```sh
$ gulp lint
```

License
-------

The project is licensed under the MIT license.
