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
PivotTable = require 'pivottable'


Tabulator = require 'tabulator-tables'

global.QuestionSet = require '../models/QuestionSet'

class ResultsView extends Backbone.View
  events: =>
    "click #download": "csv"
    "click #pivotButton": "loadPivotTable"
    "click button#edit": "edit"
    "click button#delete": "delete"

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

  csv: => @tabulator.download "csv", "#{router.resultsView.questionSet.name()}-#{moment().format("YYYY-MM-DD_HHmm")}.csv"

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
    else if Jackfruit.dynamoDBClient
      #TODO store results in local pouchdb and then just get updates

      items = []

      loop

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
        )

        items.push(...for item in result.Items
          dbItem = unmarshall(item)
          item = dbItem.reporting
          item._startTime = dbItem.startTime # Need this to be able to delete
          item
        )

        break unless result.LastEvaluatedKey #lastEvaluatedKey means there are more

      Promise.resolve(items)





  render: =>
    @$el.html "
      <h2>Results for #{@questionSet.name()}</h2>
      <button id='download'>CSV</button>
      <button id='edit'>Edit</button>
      <div id='deleteDiv' style='display:none'>
        Select rows to delete then click <button id='delete'>Delete</button>.
      </div>
      <div id='tabulator'></div>
      <div>
        Number of Rows: 
        <span id='numberRows'></span>
      </div>
      <div id='pivotTableDiv'>
        For more complicated groupings and comparisons you can create a <button id='pivotButton'>Pivot Table</button>. The pivot table can also output CSV data that can be copy and pasted into a spreadsheet.
        <div id='pivotTable'></div>
      </div>
      <style>
        #{@css()}
      </style>
    "
    results = await @getResults()

    orderedColumnNames = @questionSet.data.questions.map (question) => question.label

    columnNamesFromData = {}
    for result in _(results).sample(10000) # In case we have results from older question sets with different questions we will find it here. Use sample to put an upper limit on how many to check. (If the number of results is less than the sample target it just uses the number of results.
      for key in Object.keys(result)
        columnNamesFromData[key] = true

    # Merge the column names with the current question order taking preference
    for columnName in Object.keys(columnNamesFromData)
      unless orderedColumnNames.includes(columnName)
        orderedColumnNames.push columnName

    columnsWithPeriodRemoved = []
    columns = for column in orderedColumnNames
      field = if column.match(/\./)
        columnsWithPeriodRemoved.push column
        column.replace(/\./,"")
      else
        column

      {
        title: column
        field: field
        headerFilter: "input"
      }

    columns.unshift
      formatter:"rowSelection"
      titleFormatter:"rowSelection"
      align:"center"
      headerSort:false

    if columnsWithPeriodRemoved.length > 0
      for result in results
        for column in columnsWithPeriodRemoved
          result[column.replace(/\./,"")] = result[column]

    @tabulator = new Tabulator "#tabulator",
      height: 400
      columns: columns
      data: results
      dataFiltered: (filters, rows) =>
        @$("#numberRows").html(rows.length)
      dataLoaded: (data) =>
        @$("#numberRows").html(data.length)
    @tabulator.getColumns()[0].hide()
    @tabulator.getColumn("_startTime").hide()

  loadPivotTable: =>
    data = @tabulator.getData("active")
    console.log data

    @$("#pivotTable").pivotUI data,
      rows: ["complete"]
      cols: ["timeStarted"]
      rendererName: "Heatmap"
      renderers: _($.pivotUtilities.renderers).extend "CSV Export": (pivotData, opts) ->
        defaults = localeStrings: {}

        opts = $.extend(true, {}, defaults, opts)

        rowKeys = pivotData.getRowKeys()
        rowKeys.push [] if rowKeys.length == 0
        colKeys = pivotData.getColKeys()
        colKeys.push [] if colKeys.length == 0
        rowAttrs = pivotData.rowAttrs
        colAttrs = pivotData.colAttrs

        result = []

        row = []
        for rowAttr in rowAttrs
            row.push rowAttr
        if colKeys.length == 1 and colKeys[0].length == 0
            row.push pivotData.aggregatorName
        else
            for colKey in colKeys
                row.push colKey.join("-")

        result.push row

        for rowKey in rowKeys
            row = []
            for r in rowKey
                row.push r

            for colKey in colKeys
                agg = pivotData.getAggregator(rowKey, colKey)
                if agg.value()?
                    row.push agg.value()
                else
                    row.push ""
            result.push row
        text = ""
        for r in result
            text += r.join(",")+"\n"

        return $("<textarea>").text(text).css(
                width: ($(window).width() / 2) + "px",
                height: ($(window).height() / 2) + "px")

  css: => "
.pvtUi{color:#333}table.pvtTable{font-size:8pt;text-align:left;border-collapse:collapse}table.pvtTable tbody tr th,table.pvtTable thead tr th{background-color:#e6EEEE;border:1px solid #CDCDCD;font-size:8pt;padding:5px}table.pvtTable .pvtColLabel{text-align:center}table.pvtTable .pvtTotalLabel{text-align:right}table.pvtTable tbody tr td{color:#3D3D3D;padding:5px;background-color:#FFF;border:1px solid #CDCDCD;vertical-align:top;text-align:right}.pvtGrandTotal,.pvtTotal{font-weight:700}.pvtVals{text-align:center;white-space:nowrap}.pvtColOrder,.pvtRowOrder{cursor:pointer;width:15px;margin-left:5px;display:inline-block}.pvtAggregator{margin-bottom:5px}.pvtAxisContainer,.pvtVals{border:1px solid gray;background:#EEE;padding:5px;min-width:20px;min-height:20px;user-select:none;-webkit-user-select:none;-moz-user-select:none;-khtml-user-select:none;-ms-user-select:none}.pvtAxisContainer li{padding:8px 6px;list-style-type:none;cursor:move}.pvtAxisContainer li.pvtPlaceholder{-webkit-border-radius:5px;padding:3px 15px;-moz-border-radius:5px;border-radius:5px;border:1px dashed #aaa}.pvtAxisContainer li span.pvtAttr{-webkit-text-size-adjust:100%;background:#F3F3F3;border:1px solid #DEDEDE;padding:2px 5px;white-space:nowrap;-webkit-border-radius:5px;-moz-border-radius:5px;border-radius:5px}.pvtTriangle{cursor:pointer;color:grey}.pvtHorizList li{display:inline}.pvtVertList{vertical-align:top}.pvtFilteredAttribute{font-style:italic}.pvtFilterBox{z-index:100;width:300px;border:1px solid gray;background-color:#fff;position:absolute;text-align:center}.pvtFilterBox h4{margin:15px}.pvtFilterBox p{margin:10px auto}.pvtFilterBox label{font-weight:400}.pvtFilterBox input[type=checkbox]{margin-right:10px;margin-left:10px}.pvtFilterBox input[type=text]{width:230px}.pvtFilterBox .count{color:gray;font-weight:400;margin-left:3px}.pvtCheckContainer{text-align:left;font-size:14px;white-space:nowrap;overflow-y:scroll;width:100%;max-height:250px;border-top:1px solid #d3d3d3;border-bottom:1px solid #d3d3d3}.pvtCheckContainer p{margin:5px}.pvtRendererArea{padding:5px}
  "

module.exports = ResultsView
