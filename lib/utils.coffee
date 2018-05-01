Promise = require('bluebird')

exports.extract = (stream) ->
	new Promise (resolve, reject) ->
		chunks = []
		stream.on('error', reject)
		stream.on 'data', (chunk) ->
			chunks.push(chunk)
		stream.on 'end', ->
			resolve(chunks.join(''))

exports.waitStream = (stream) ->
	new Promise (resolve, reject) ->
		stream.on('error', reject)
		stream.on('close', resolve)
