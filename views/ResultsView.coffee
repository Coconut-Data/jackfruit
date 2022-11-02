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

{QueryCommand,DeleteItemCommand} = require "@aws-sdk/client-dynamodb"
{marshall,unmarshall} = require("@aws-sdk/util-dynamodb")

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


  ## MOVE THESE TO TabulatorView ##
  edit: =>
    if Jackfruit.dynamoDBClient
      @$("#deleteDiv").show()
      @tabulator.getColumns()[0].show()

  delete: =>
    itemsToDelete = @tabulator.getSelectedData()
    if itemsToDelete.length  > 0 and confirm "Are you sure you want to delete #{itemsToDelete.length} items?"
      @$("#tabulator").html "Deleting selected items, please wait..."
      await Promise.all(for item in itemsToDelete
        Jackfruit.dynamoDBClient.send(
          new DeleteItemCommand
            TableName: "Gateway-#{@databaseName}"
            Key: 
              marshall
                startTime: item._startTime
                source: item.source

        )
      )
      @render()

  getResults: =>
    questionSetName = @questionSet.name()


    if Jackfruit.database

      startkey = "result-#{underscored(questionSetName.toLowerCase())}"
      endkey = "result-#{underscored(questionSetName.toLowerCase())}-\ufff0"


      # Check and see if the above startkey/endkey find any data, otherwise we are probably using custom keys
      if (await Jackfruit.database.allDocs
        startkey: startkey
        endkey: endkey
        include_docs: false
        limit: 1
      ).rows.length is 0


      #### For entomological surveillance data ####
      #if Jackfruit.databaseName is "entomology_surveillance"
      #
        customIdAcronym = (idName) =>
          #create acronmym for ID
          acronym = ""
          for word in idName.split(" ")
            acronym += word[0].toUpperCase() unless ["ID","SPECIMEN","COLLECTION","INVESTIGATION"].includes word.toUpperCase()
          acronym


        console.log customIdAcronym(questionSetName)

        startkey = "result-#{customIdAcronym(questionSetName)}"
        endkey = "result-#{customIdAcronym(questionSetName)}-\ufff0"

      resultDocs = await Jackfruit.database.allDocs
        startkey: startkey
        endkey: endkey
        include_docs: true
      .then (result) => Promise.resolve _(result.rows)?.pluck "doc"
    else if Jackfruit.dynamoDBClient
      #TODO store results in local pouchdb and then just get updates

      items = []

      console.log "STARTING"

      loop

        limit = 1000

        result = await Jackfruit.dynamoDBClient.send(
          new QueryCommand
            TableName: "Gateway-#{@databaseName}"
            IndexName: "resultsByQuestionSetAndUpdateTime"
            KeyConditionExpression: 'questionSetName = :questionSetName'
            ExpressionAttributeValues:
              ':questionSetName':
                'S': questionSetName
            ScanIndexForward: false
            ExclusiveStartKey: result?.LastEvaluatedKey
            Limit: limit
        ).catch (error) => 
          console.log error
          limit = limit/2
          @$("#progress").html "Retrieved #{items.length} items. Database requests at maximum, continuing in 5 seconds."
          await new Promise((resolve) =>setTimeout(resolve, 5000))

        items.push(...for item in result.Items
          dbItem = unmarshall(item)
          item = dbItem.reporting
          item._startTime = dbItem.startTime # Need this to be able to delete
          item
        )

        break unless result.LastEvaluatedKey #lastEvaluatedKey means there are more
        @$("#progress").html "Retrieved #{items.length} items. Please wait."
        await new Promise((resolve) => setTimeout(resolve, 5000))

      @$("#progress").html ""
      Promise.resolve(items)





  render: =>
    @$el.html "
      <h2>
        Results for <a href='#questionSet/#{@serverName}/#{@databaseName}/#{@questionSet.name()}'>#{@questionSet.name()}</a> 
      </h2>
      <div id='progress'></div>
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
