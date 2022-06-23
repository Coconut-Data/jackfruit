axios = require 'axios'
qs = require 'qs'

{ GetItemCommand } = require("@aws-sdk/client-dynamodb")
{ unmarshall } = require("@aws-sdk/util-dynamodb")

class SendMessageView extends Backbone.View
  events: =>
    "click #send": "send"
    "keyup #message": "sendIfEnter"

  sendIfEnter: (event) =>
    event = event.originalEvent
    @send() if event.key is 'Enter' or event.keyCode is 13

  send: =>

    {sid,token} = @configuration.authentication

    await axios.post "https://api.twilio.com/2010-04-01/Accounts/#{sid}/Messages.json", qs.stringify({
      To: @$("#to").val()
      From:'+13103629950'
      Body: @$("#messageToSend").val()
    }), auth:
      username: sid
      password: token

  render: =>
    @$el.html "
      <div style='background-color:black; color:white;'>
      Send message
      </div>
      To: <input id='to' value=''></input><br/>
      Message: <input id='messageToSend' value=''></input>
      <button id='send'>Send</button>
    "

    result = await Jackfruit.dynamoDBClient.send(
      new GetItemCommand(
        TableName: "Configurations"
        Key: 
          gatewayName:
            "S": @gatewayName
      )
    )

    @configuration = unmarshall(result.Item)


module.exports = SendMessageView
