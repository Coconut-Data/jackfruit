$ = require 'jquery'
require 'jquery-ui-browserify'
Backbone = require 'backbone'
Backbone.$  = $
_ = require 'underscore'
dasherize = require("underscore.string/dasherize")
titleize = require("underscore.string/titleize")
humanize = require("underscore.string/humanize")
slugify = require("underscore.string/slugify")
underscored = require("underscore.string/underscored")

global.QuestionSet = require '../models/QuestionSet'

TabulatorView = require './TabulatorView'

class ResultsView extends Backbone.View
  events: =>
    "click #download": "csv"
    "click #pivotButton": "loadPivotTable"
    "click button#edit": "edit"
    "click button#delete": "delete"
    "click button#refresh": "refresh"

  refresh: =>
    @tabulatorView.tabulator.replaceData((await @getResults()))

  getResults: =>
    questionSetName = @questionSet.name()

    if Jackfruit.database

      startkey = "result-#{underscored(questionSetName.toLowerCase())}"
      endkey = "result-#{underscored(questionSetName.toLowerCase())}-\ufff0"

      #### For entomological surveillance data ####
      if Jackfruit.databaseName is "entomology_surveillance"
      #
        acronymForEnto = (idName) =>
          #create acronmym for ID
          acronym = ""
          for word in idName.split(" ")
            acronym += word[0].toUpperCase() unless ["ID","SPECIMEN","COLLECTION","INVESTIGATION"].includes word.toUpperCase()
          acronym

        startkey = "result-#{acronymForEnto(questionSetName)}"
        endkey = "result-#{acronymForEnto(questionSetName)}-\ufff0"

      resultDocs = await Jackfruit.database.allDocs
        startkey: startkey
        endkey: endkey
        include_docs: true
      .then (result) => Promise.resolve _(result.rows)?.pluck "doc"


  render: =>
    @$el.html "
      <h2>
        Results for <a href='#questionSet/#{@serverName}/#{@databaseName}/#{@questionSet.name()}'>#{@questionSet.name()}</a> 
      </h2>
      <button id='refresh'>Refresh</button>
      <div id='tabulatorView'>
      </div>
    "

    @tabulatorView = new TabulatorView()
    @tabulatorView.questionSet = @questionSet
    @tabulatorView.data = await @getResults()
    @tabulatorView.setElement("#tabulatorView")
    @tabulatorView.render()




  css: => "
.pvtUi{color:#333}table.pvtTable{font-size:8pt;text-align:left;border-collapse:collapse}table.pvtTable tbody tr th,table.pvtTable thead tr th{background-color:#e6EEEE;border:1px solid #CDCDCD;font-size:8pt;padding:5px}table.pvtTable .pvtColLabel{text-align:center}table.pvtTable .pvtTotalLabel{text-align:right}table.pvtTable tbody tr td{color:#3D3D3D;padding:5px;background-color:#FFF;border:1px solid #CDCDCD;vertical-align:top;text-align:right}.pvtGrandTotal,.pvtTotal{font-weight:700}.pvtVals{text-align:center;white-space:nowrap}.pvtColOrder,.pvtRowOrder{cursor:pointer;width:15px;margin-left:5px;display:inline-block}.pvtAggregator{margin-bottom:5px}.pvtAxisContainer,.pvtVals{border:1px solid gray;background:#EEE;padding:5px;min-width:20px;min-height:20px;user-select:none;-webkit-user-select:none;-moz-user-select:none;-khtml-user-select:none;-ms-user-select:none}.pvtAxisContainer li{padding:8px 6px;list-style-type:none;cursor:move}.pvtAxisContainer li.pvtPlaceholder{-webkit-border-radius:5px;padding:3px 15px;-moz-border-radius:5px;border-radius:5px;border:1px dashed #aaa}.pvtAxisContainer li span.pvtAttr{-webkit-text-size-adjust:100%;background:#F3F3F3;border:1px solid #DEDEDE;padding:2px 5px;white-space:nowrap;-webkit-border-radius:5px;-moz-border-radius:5px;border-radius:5px}.pvtTriangle{cursor:pointer;color:grey}.pvtHorizList li{display:inline}.pvtVertList{vertical-align:top}.pvtFilteredAttribute{font-style:italic}.pvtFilterBox{z-index:100;width:300px;border:1px solid gray;background-color:#fff;position:absolute;text-align:center}.pvtFilterBox h4{margin:15px}.pvtFilterBox p{margin:10px auto}.pvtFilterBox label{font-weight:400}.pvtFilterBox input[type=checkbox]{margin-right:10px;margin-left:10px}.pvtFilterBox input[type=text]{width:230px}.pvtFilterBox .count{color:gray;font-weight:400;margin-left:3px}.pvtCheckContainer{text-align:left;font-size:14px;white-space:nowrap;overflow-y:scroll;width:100%;max-height:250px;border-top:1px solid #d3d3d3;border-bottom:1px solid #d3d3d3}.pvtCheckContainer p{margin:5px}.pvtRendererArea{padding:5px}
  "

module.exports = ResultsView
