Initiator = require '../models/Initiator'

class InitiateQuestionSetForNumberView extends Backbone.View
  events: =>
    "click #start": "start"

  start: =>
    target = @$("#to").val()
    interactionType = @$('input[name=interactionType]:checked').val()

    @initiator.initiate(target.replace(/ /g,""), interactionType)

  render: =>
    @$el.html "
      <div style='background-color:black; color:white;'>
      Start this question set for number
      </div>

      <input type='radio' checked='true' name='interactionType' value='text'>
      <label for='male'>Text</label>
      <input type='radio' name='interactionType' value='ivr'>
      <label for='female'>IVR</label>
      <br>


      Target: <input id='to' value=''></input><br/>
      <button id='start'>Start</button>
    "

    @initiator = new Initiator(@gatewayName,@questionSetName)

module.exports = InitiateQuestionSetForNumberView
