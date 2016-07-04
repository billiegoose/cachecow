Cache = require('..')
assert = require('assert')
fs = require('fs-extra')
Readable = require('stream').Readable

stream = (str) ->
  s = new Readable
  s.go = ->
    process.nextTick ->
      s.push str
      s.push null
    return s
  return s

string = (str) ->
  s = ''
  str.on 'data', (chunk) ->
    s += chunk.toString()


delay = (delay, cb) ->
  return (args...) ->
    setTimeout () ->
      cb(args...)
    , delay

  # c.init ->
  #   console.log c
  #   c.get 'test/cache2.coffee', (err, foo) ->
  #     c.get 'test/cache2.coffee', delay 300, (err, foo) ->
  #       c.get 'test/cache1.coffee', (err, foo) ->
  #         console.log c.cache
  #         console.log foo
  #         c.clean()
  #
  #
  # fGet = (filename, callback) ->
  #   console.log "GETTING"
  #   callback null, "Some random text"
describe 'cachecow', ->
  describe 'put / get', ->
    c = null

    before ->
      c = new Cache()

    it 'put', (done) ->
      c.put 'test/qwer', stream('This is some text.').go(), delay 25, (err) ->
        assert.ifError err
        assert.equal(c.used_space, 18)
        done()

    it 'put', (done) ->
      c.put 'test/asdf', stream('This is some more text.').go(), delay 25, (err) ->
        assert.ifError err
        assert.equal(c.used_space, 41)
        done()

    it 'put', (done) ->
      c.put 'test/zxcv', stream('This is even more text.').go(), delay 25, (err) ->
        assert.ifError err
        assert.equal(c.used_space, 64)
        done()

    it 'get', (done) ->
      c.get 'test/qwer', delay 25, (err, foo) ->
        assert.ifError err
        assert.equal(foo.read(), 'This is some text.')
        done()

    it 'get', (done) ->
      c.get 'test/asdf', delay 25, (err, foo) ->
        assert.ifError err
        assert.equal(foo.read(), 'This is some more text.')
        done()

    it 'get', (done) ->
      c.get 'test/zxcv', delay 25, (err, foo) ->
        assert.ifError err
        assert.equal(foo.read(), 'This is even more text.')
        done()

  describe 'getter', ->
    c = null
    callcount = 0
    fGet = (filename, callback) ->
      callcount += 1
      callback null, stream("Some text").go()

    before ->
      c = new Cache({getter: fGet})

    it 'getter', (done) ->
      c.get 'test/asdf', delay 25, (err, foo) ->
        assert.ifError err
        assert.equal(callcount, 1)
        assert.equal(foo.read(), 'Some text')
        done()

    it 'get', (done) ->
      c.get 'test/asdf', delay 25, (err, foo) ->
        assert.ifError err
        assert.equal(callcount, 1)
        assert.equal(foo.read(), 'Some text')
        done()

  describe.skip 'DeleteByLastAccess', ->
    c = null
    before ->
      c = new Cache
        maxsize: 100
        DeleteByFileSize: 0
        DeleteByTotalReads: 0
        DeleteByLastAccess: 1

    it '(setup)', (done) ->
      c.put 'test/1', stream('1234567810').go(), ->
        assert.equal(c.used_space, 10)
        c.put 'test/2', stream('123456789111315').go(), ->
          assert.equal(c.used_space, 25)
          c.put 'test/3', stream('1234567891113151719212325').go(), ->
            assert.equal(c.used_space, 50)
            c.put 'test/4', stream('1234567891113151719212325').go(), ->
              assert.equal(c.used_space, 75)
              c.get 'test/1', -> # Instead of deleting this one, it'll delete test/2
                done()

    it 'overflow', (done) ->
      c.put 'test/5', stream('123456789111315').go(), ->
        assert.equal(c.used_space, 50)
        assert.doesNotThrow(-> fs.accessSync(c.options.dir + '/test/1'))
        assert.throws      (-> fs.accessSync(c.options.dir + '/test/2'))
        assert.throws      (-> fs.accessSync(c.options.dir + '/test/3'))
        assert.doesNotThrow(-> fs.accessSync(c.options.dir + '/test/4'))
        assert.doesNotThrow(-> fs.accessSync(c.options.dir + '/test/5'))
        done()


  describe 'DeleteByFileSize', ->
    c = null
    before ->
      c = new Cache
        maxsize: 100
        DeleteByFileSize: 1
        DeleteByTotalReads: 0
        DeleteByLastAccess: 0

    it '(setup)', (done) ->
      c.put 'test/1', stream('1234567810').go(), ->
        assert.equal(c.used_space, 10)
        c.put 'test/2', stream('123456789111315').go(), ->
          assert.equal(c.used_space, 25)
          c.put 'test/3', stream('1234567891113151719212325').go(), ->
            assert.equal(c.used_space, 50)
            c.put 'test/4', stream('12345678911131517.20').go(), ->
              assert.equal(c.used_space, 70)
              done()

    it 'overflow', (done) ->
      c.put 'test/5', stream('12345678911131517.20').go(), ->
        assert.equal(c.used_space, 65)
        assert.doesNotThrow(-> fs.accessSync(c.options.dir + '/test/1'))
        assert.doesNotThrow(-> fs.accessSync(c.options.dir + '/test/2'))
        assert.throws      (-> fs.accessSync(c.options.dir + '/test/3'))
        assert.doesNotThrow(-> fs.accessSync(c.options.dir + '/test/4'))
        assert.doesNotThrow(-> fs.accessSync(c.options.dir + '/test/5'))
        done()

    it 'overflow two files', (done) ->
      c.put 'test/6', stream('1234567810').go(), ->
        assert.equal(c.used_space, 75)
        c.put 'test/7', stream('1234567810').go(), ->
          assert.equal(c.used_space, 85)
          c.put 'test/8', stream('1234567810').go(), ->
            assert.equal(c.used_space, 75)
            c.put 'test/9', stream('1234567810').go(), ->
              assert.equal(c.used_space, 85)
              c.put 'test/10', stream('1234567810').go(), ->
                assert.equal(c.used_space, 75)
                assert.doesNotThrow(-> fs.accessSync(c.options.dir + '/test/1'))
                assert.doesNotThrow(-> fs.accessSync(c.options.dir + '/test/2'))
                assert.throws      (-> fs.accessSync(c.options.dir + '/test/3'))
                assert.throws      (-> fs.accessSync(c.options.dir + '/test/4'))
                assert.throws      (-> fs.accessSync(c.options.dir + '/test/5'))
                assert.doesNotThrow(-> fs.accessSync(c.options.dir + '/test/6'))
                assert.doesNotThrow(-> fs.accessSync(c.options.dir + '/test/7'))
                assert.doesNotThrow(-> fs.accessSync(c.options.dir + '/test/8'))
                assert.doesNotThrow(-> fs.accessSync(c.options.dir + '/test/9'))
                assert.doesNotThrow(-> fs.accessSync(c.options.dir + '/test/10'))
                done()

  describe 'DeleteByTotalReads', ->
    c = null
    before ->
      c = new Cache
        maxsize: 100
        DeleteByFileSize: 0
        DeleteByTotalReads: 1
        DeleteByLastAccess: 0

    it '(setup)', (done) ->
      c.put 'test/1', stream('1234567810').go(), ->
        assert.equal(c.used_space, 10)
        c.put 'test/2', stream('123456789111315').go(), ->
          assert.equal(c.used_space, 25)
          c.put 'test/3', stream('1234567891113151719212325').go(), ->
            assert.equal(c.used_space, 50)
            c.put 'test/4', stream('12345678911131517.20').go(), ->
              assert.equal(c.used_space, 70)
              c.get 'test/1', ->
                c.get 'test/1', ->
                  c.get 'test/3', ->
                    c.get 'test/4', ->
                      done()

    it 'overflow', (done) ->
      c.put 'test/5', stream('12345678911131517.20').go(), ->
        assert.equal(c.used_space, 55)
        assert.doesNotThrow(-> fs.accessSync(c.options.dir + '/test/1'))
        assert.throws      (-> fs.accessSync(c.options.dir + '/test/2'))
        assert.doesNotThrow(-> fs.accessSync(c.options.dir + '/test/3'))
        assert.doesNotThrow(-> fs.accessSync(c.options.dir + '/test/4'))
        assert.throws      (-> fs.accessSync(c.options.dir + '/test/5'))
        done()
