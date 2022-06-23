Initiator = require '../models/Initiator'
InteractView = require './InteractView'
SendMessageView = require './SendMessageView'
InitiateQuestionSetForNumberView = require './InitiateQuestionSetForNumberView'
Tabulator = require 'tabulator-tables'
titleize = require("underscore.string/titleize")

class MessagingView extends Backbone.View
  events: =>
    "click #addToQueue": "addToQueue"
    "click #processQueue": "processQueue"
    "click #pauseQueue": "pauseQueue"
    "click #reQueue": "reQueue"
    "click #clearQueue": "clearQueue"

  reQueue: =>
    for number, data of @queue
      data["Status"] = "Queued"
    @saveAndUpdateQueue()

  clearQueue: =>
    @log "Queue Cleared"
    @queue = {}
    @saveAndUpdateQueue()

  log: (data, includeNewLine = true) =>
    console.log data
    @$("#log").append data
    @$("#log").append "<br/>" unless includeNewLine is false
    @$("#log")[0].scrollTop = @$("#log")[0].scrollHeight

  addToQueue: =>
    numbers = @$("textarea").val().split(/\n|, *| +/)
    @queue or= {}
    type = if @questionSet.idOrName is "IVR"
      "ivr"
    else
      @$('input[name=queueInteractionType]:checked').val()

    for number in numbers
      number = number.trim()
      if isNaN(number) or number is ""
        @log "#{number} is not a valid number"
      else
        if @queue[number]?.Status is "Queued"
          console.log number

          @log "Already queued"
        else
          @queue[number] = {
            Number: number
            Status: "Queued"
            Type: type
            "Last Updated": Date.now()
          }
    @saveAndUpdateQueue()
    @$("textarea").val("")
      
  saveAndUpdateQueue: =>
    Jackfruit.queueDatabase.upsert "queue", (doc) => 
      doc.data = @queue
      doc

    @tabulator.replaceData Object.values(@queue)

  processQueue: =>
    delaySeconds = parseInt(@$("#delay").val())
    #@$("#processQueue").hide()
    @$("#pauseQueue").show()
    @pause = false

    numbersQueuedAndSortedByLastUpdate = _(@queue).chain().filter (data, number) =>
      data.Status = "Queued"
    .sortBy("Last Updated")
    .values()
    .value()

    for data in numbersQueuedAndSortedByLastUpdate
      return if @pause
      await @initiator.initiate(data.Number, data.Type)
      .then (error) =>
        @log "#{data.Number} processed"
        @queue[data.Number]["Status"] = "Sent"
        Promise.resolve()
      .catch (error) =>
        console.error error
        @log "#{data.Number} error:"
        @log error.response?.data?.message
        @queue[data.Number]["Status"] = error.response?.data?.message
        Promise.resolve()
      await new Promise (resolve) => 
        _.delay =>
          resolve()
        , delaySeconds * 1000
      @saveAndUpdateQueue()
    @$("#processQueue").show()
    @$("#pauseQueue").hide()

  pauseQueue: =>
    @$("#processQueue").show()
    @$("#pauseQueue").hide()
    @pause = true

  render: =>
    @$el.html "
      <div style='float:right; width:200px; border: 1px solid;'>
        <div style='width:200px; border: 1px solid;' id='interact'/>
        <hr/>
        <div style='width:200px; border: 1px solid;' id='sendMessage'/>
        <hr/>
        <div style='width:200px; border: 1px solid;' id='initiateQuestionSetForNumber'/>
      </div>
      <h2>
        Gateway: <a href='#gateway/#{@serverName}/#{@databaseOrGatewayName}'>#{@databaseOrGatewayName}</a>
      </h2>
      <h2>
        Question Set: <a href='#questionSet/#{@serverName}/#{@databaseOrGatewayName}/#{@questionSet.idOrName}'>
          #{titleize(@questionSet.name())}
        </a>
      </h2>
      To initiate this question set for multiple people, add their phone numbers below, separated either by a comma or newline. Then press the queue button to add the numbers to the queue. You can then start processing the numbers in the queue by pressing the process button. If you want to add a delay between processing each item in tue queue, then change the delay value.
      <div id='log' style='
        height: 200px;
        width:400px; 
        background-color:black; 
        color:yellow; 
        font-family: monospace;
        overflow: scroll;
        '
      >
      </div>
      <br/>
      Numbers to add to queue:<br/>

      <textarea></textarea>
      <br/>
      <div id='typeOfItemToQueueSelector'>
        <input type='radio' id='text' name='queueInteractionType' value='text' checked='checked'></input>
        <label for='text'>Text</label>
        <input type='radio' id='ivr' name='queueInteractionType' value='ivr'></input>
        <label for='ivr'>IVR</label>
      </div>

      <button id='addToQueue'>Add to queue</button>
      <br/>
      <h2>Queue</h2>
      Seconds to delay between processing queue items: <input id='delay' value='1'></input>
      <br/>
      <button id='processQueue'>Process items in the queue</button>
      <button style='display:none' id='pauseQueue'>Pause Queue</button>
      <button id='reQueue'>Requeue All Items</button>
      <button id='clearQueue'>Clear Queue</button>
      <button id='download'>CSV</button>
      <div id='tabulator'></div>
      <div>
        Number of Rows: 
        <span id='numberRows'></span>
      </div>
    "


    if @questionSet.idOrName is "IVR"
      @$("#typeOfItemToQueueSelector").hide()

    @interactView = new InteractView()
    @interactView.questionSetName = @questionSet.idOrName
    @interactView.setElement @$("#interact")
    @interactView.render()

    @sendMessageView = new SendMessageView()
    @sendMessageView.gatewayName = @databaseOrGatewayName
    @sendMessageView.setElement @$("#sendMessage")
    @sendMessageView.render()

    @initiateQuestionSetForNumber = new InitiateQuestionSetForNumberView()
    @initiateQuestionSetForNumber.gatewayName = @databaseOrGatewayName
    @initiateQuestionSetForNumber.questionSetName = @questionSet.idOrName
    @initiateQuestionSetForNumber.setElement @$("#initiateQuestionSetForNumber")
    @initiateQuestionSetForNumber.render()

    await @setupQueue()
    @initiator = new Initiator(@databaseOrGatewayName,@questionSet.idOrName)

  setupQueue: =>
    @tabulator = new Tabulator "#tabulator",
      height: 400
      columns: for column in ["Number", "Status", "Last Updated"]
        {
          title: column
          field: column
          headerFilter: "input"
        }
      initialSort:[
        {column:"Last Updated", dir:"asc"}
      ]
      data: []
      dataFiltered: (filters, rows) =>
        @$("#numberRows").html(rows.length)
      dataLoaded: (data) =>
        @$("#numberRows").html(data.length)

    Jackfruit.queueDatabase = new PouchDB("queue")
    @queue = (await Jackfruit.queueDatabase.get "queue")?.data
    if @queue is null
      @queue = {}
    @saveAndUpdateQueue()
    

module.exports = MessagingView
