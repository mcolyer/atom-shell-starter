Menu = require 'menu'
BrowserWindow = require 'browser-window'
app = require 'app'
fs = require 'fs-plus'
ipc = require 'ipc'
path = require 'path'
os = require 'os'
net = require 'net'
url = require 'url'

{EventEmitter} = require 'events'
_ = require 'underscore-plus'
{spawn} = require 'child_process'

AppMenu = require './appmenu'
AppWindow = require './appwindow'

module.exports =
class Application
  _.extend @prototype, EventEmitter.prototype

  constructor: (options) ->
    {@resourcePath, @version, @devMode } = options

    @pkgJson = require '../../package.json'
    @windows = []

    @openWithOptions(options)

  # Opens a new window based on the options provided.
  openWithOptions: (options) ->
    {devMode, test, exitWhenDone, specDirectory, logFile} = options

    if test
      appWindow = @runSpecs({exitWhenDone, @resourcePath, specDirectory, devMode, logFile})
    else
      appWindow = new AppWindow(options)
      @menu = new AppMenu(pkg: @pkgJson)

      @menu.attachToWindow(appWindow)
      @handleMenuItems(@menu)

    appWindow.show()
    @windows.push(appWindow)
    appWindow.on 'closed', =>
      @removeAppWindow(appWindow)

  handleMenuItems: (menu) ->
    menu.on 'application:quit', -> app.quit()

    menu.on 'window:reload', ->
      BrowserWindow.getFocusedWindow().reload()

    menu.on 'window:toggle-full-screen', ->
      BrowserWindow.getFocusedWindow().toggleFullScreen()

    menu.on 'window:toggle-dev-tools', ->
      BrowserWindow.getFocusedWindow().toggleDevTools()

    menu.on 'application:run-specs', =>
      @openWithOptions(test: true)

  removeAppWindow: (appWindow) =>
    @windows.splice(idx, 1) for w, idx in @windows when w is appWindow

  # Opens up a new {AtomWindow} to run specs within.
  #
  # options -
  #   :resourcePath - The path to include specs from.
  #   :specPath - The directory to load specs from.
  #   :logfile - The file path to log output to.
  runSpecs: ({exitWhenDone, resourcePath, specDirectory, logFile}) ->
    if resourcePath isnt @resourcePath and not fs.existsSync(resourcePath)
      resourcePath = @resourcePath

    try
      bootstrapScript = require.resolve(path.resolve(global.devResourcePath, 'spec', 'spec-bootstrap'))
    catch error
      bootstrapScript = require.resolve(path.resolve(__dirname, '..', '..', 'spec', 'spec-bootstrap'))

    isSpec = true
    devMode = true
    new AppWindow({bootstrapScript, exitWhenDone, resourcePath, isSpec, devMode, specDirectory, logFile})
