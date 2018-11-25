Backbone = require 'backbone'
global.$ = require 'jquery'
Backbone.$  = $

Router = require './Router'

global.Jackfruit = {}
global.router = new Router()

Backbone.history.start()
