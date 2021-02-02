$ = require 'jquery'
Backbone = require 'backbone'
Backbone.$  = $
_ = require 'underscore'
dasherize = require("underscore.string/dasherize")
titleize = require("underscore.string/titleize")
humanize = require("underscore.string/humanize")
slugify = require("underscore.string/slugify")
underscored = require("underscore.string/underscored")


Tabulator = require 'tabulator-tables'

global.QuestionSet = require '../models/QuestionSet'

class ResultsView extends Backbone.View
  events: =>
    "click #download": "csv"

  csv: => @tabulator.download "csv", "CoconutTableExport.csv"

  getResults: =>
    questionSetName = @questionSet.name()
    resultDocs = await Jackfruit.database.allDocs
      startkey: "result-#{underscored(questionSetName.toLowerCase())}"
      endkey: "result-#{underscored(questionSetName.toLowerCase())}-\ufff0"
      include_docs: true
    .then (result) => Promise.resolve _(result.rows)?.pluck "doc"

  render: =>
    @$el.html "
      <h2>Results for #{@questionSet.name()}</h2>
      <button id='download'>CSV ↓</button> <small>Add more fields by clicking the box below</small>
      <div id='tabulator'></div>
    "
    results = await @getResults()

    columns = {}

    for result in _(results).sample(200)
      for key in Object.keys(result)
        columns[key] = true

    columns = for column in Object.keys(columns)
      {
        title: column
        field: column
      }

    console.log columns
    console.log results


    @tabulator = new Tabulator "#tabulator",
      height: 800
      columns: columns
      data: results




module.exports = ResultsView
