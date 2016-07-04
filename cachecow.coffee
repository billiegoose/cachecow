# A simple disk cache system that won't eat the whole hard disk
upath = require 'upath'
fs = require 'fs-extra'
os = require 'os'

class Cache
  constructor: (opts) ->
    self = this
    defaults =
      maxsize: 1024*1024*1 # 1MB
      dir: upath.join(os.tmpdir(), 'cachecow')
      getter: ->
        console.log 'You must define a getter function for cache misses!'
      DeleteByFileSize: 0
      DeleteByTotalReads: 0
      DeleteByLastAccess: 1

    self.options = Object.assign({}, defaults, opts)

    fs.ensureDirSync(self.options.dir)
    self.used_space = 0
    self.cache = {}

  init: (callback) ->
    self = this
    now = Date.now()
    self.used_space = 0
    fs.walk(self.options.dir)
    .on 'data', ({stats, path}) ->
      if stats.isFile()
        key = upath.relative(self.options.dir, path)
        self.cache[key] =
          ident: key
          size: stats.size
          reads: 0
          accessed: now
        self.used_space += stats.size
    .on 'end', callback

  put: (filename, stream, callback) ->
    self = this
    fs.ensureFile self.options.dir + '/' + filename, (err) ->
      return callback err if err?
      disk = fs.createWriteStream self.options.dir + '/' + filename
      disk.on 'error', (err) ->
        callback err
      disk.on 'close', ->
        self.cache[filename] =
          ident: filename
          size: disk.bytesWritten
          reads: 0
          accessed: Date.now()
        self.used_space += self.cache[filename].size
        self.clean callback
      stream.pipe(disk)

  clean: (callback) ->
    self = this
    # Clean if we reach 90% disk space
    return callback() if self.used_space < 0.9 * self.options.maxsize
    # Create sorted list
    list = []
    for key, value of self.cache
      list.push value
    # (big to small) (rarely read to frequently read) (accessed long ago to accessed recently)
    list.sort (a, b) -> (b.size - a.size)*self.options.DeleteByFileSize + (a.reads - b.reads)*self.options.DeleteByTotalReads + (a.accessed - b.accessed)*self.options.DeleteByLastAccess
    removed_space = 0
    # Delete files until we're down to 70% disk space
    while removed_space < 0.2 * self.options.maxsize
      a = list.shift()
      removed_space += a.size
      fs.unlink(self.options.dir + '/' + a.ident)
      delete self.cache[a.ident]
      self.used_space -= a.size
    return callback()

  get: (filename, callback) ->
    self = this
    a = self.cache[filename]
    if a?
      a.reads += 1
      a.accessed = Date.now()
      disk = fs.createReadStream self.options.dir + '/' + filename
      callback null, disk
    else
      self.options.getter filename, (err, stream) ->
        return callback err if err?
        self.put filename, stream, (err) ->
          return callback err if err?
          self.get filename, callback

module.exports = Cache
