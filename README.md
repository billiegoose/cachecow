# Cache Cow
All the caching modules I found on npm were for caching things in memory, or in an external service like Redis.
I couldn't find any cache modules on npm that fit my need, so I wrote this one.

# Motivation

 1. Do you have extra hard drive space?
 2. Store some of your files in the cloud or whatever?
 3. Want to save bandwidth or time by making fewer fetches to that cloud?

That is the use case this module is designed for.
I wanted to use the hard drive to cache files that are in remote storage like Amazon S3.

# Features
 - When cache reaches 90% of the defined `maxsize` it deletes files until the cache is 70% of `maxsize`.
 - Returns streams, not buffers, for faster requests.
 - How it chooses which files to delete can be customized

# Example

```coffee
# Hypothetical example using CacheCow with an HTTP proxy server
express = require('express')
request = require('request')
CacheCow = require('cachecow')

app = express()

cache = new CacheCow({
  maxsize: 1024*1024*1024*10 # 10GB
  # Define a function to deal with cache misses
  getter: (filename, callback) ->
    log.info "Not found in cache"
    stream = request("http://my.other.server/#{filename}")
    callback(null, stream)
})

# Retrieve something from cache
app.get ":filepath", (req, res) ->
  cache.get req.params.filepath, (err, stream) ->
    return res.status(404).send(err.message) if err?
    stream.pipe res

# This scans the cache directory to gather file size information for any files
# already present in the cache.
cache.init()

app.listen(8080)
```

# Options
```coffee
CacheCow = require 'cachecow'

# Default values
cache = new CacheCow
  maxsize: 1024*1024*1 # 1MB
  dir: upath.join(os.tmpdir(), 'cachecow')
  getter: ->
    console.log 'You must define a getter function for cache misses!'
  # Weights used in garbage collection equation
  DeleteByFileSize: 0      # Delete big files first, keep as many files as possible
  DeleteByTotalReads: 0    # Delete rarely used files, keep file that are frequently fetched
  DeleteByLastAccess: 1    # Delete old files, keep files that have been recently fetched
```
