axios = require 'axios'

class InteractView extends Backbone.View
  events: =>
    "click #send": "send"
    "keyup #message": "sendIfEnter"

  sendIfEnter: (event) =>
    event = event.originalEvent
    @send() if event.key is 'Enter' or event.keyCode is 13

  send: =>
    request = @$("#message").val()
    @$("#messages").append "
      <div class='request'>
        #{request}
      </div>
    "
    @$("#message").val("")
    response = await axios(
      method: 'post'
      url: Jackfruit.gooseberryEndpoint
      data:
        message: request
        from: "jackfruit"
        gateway: Jackfruit.gateway.gatewayName
    )
    .catch (error) =>
      console.error error


    @$("#messages").append "
      <div class='response'>
        #{response.data}
      </div>
    "

  render: =>
    @$el.html "
      <style>
        .request{
          background-color: lightgreen;
        }
        .response{
          background-color: gray;
        }
        #messages{
          overflow: scroll;
          height: 500px;
        }
      </style>
      <div style='background-color:black; color:white;'>
      Send messages to Gateway #{Jackfruit.gateway.gatewayName}
      </div>
      <div id='messages'></div>
      <input id='message' value='Start #{router.questionSetView.questionSet.idOrName}'></input>
      <button id='send'>Send</button>
    "

module.exports = InteractView
