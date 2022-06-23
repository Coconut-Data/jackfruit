
axios = require 'axios'
qs = require 'qs'

{ GetItemCommand } = require("@aws-sdk/client-dynamodb")
{ unmarshall } = require("@aws-sdk/util-dynamodb")

class Initiator
  constructor: (@gatewayName, @questionSetName) ->

  initiate: (target, interactionType) =>

    unless @configuration

      result = await Jackfruit.dynamoDBClient.send(
        new GetItemCommand(
          TableName: "Configurations"
          Key: 
            gatewayName:
              "S": @gatewayName
        )
      )

      @configuration = unmarshall(result.Item)

    {sid,token} = @configuration.authentication

    data = {
      To: target
      From: @configuration.phoneNumber
    }

    if interactionType is "text"

      # First start off the interaction by sending the START message

      response = await axios(
        method: 'post'
        url: Jackfruit.gooseberryEndpoint
        data:
          message: "Start #{@questionSetName}"
          from: target.replace(/ /g,"")
          gateway: @gatewayName
      )

      url = "https://api.twilio.com/2010-04-01/Accounts/#{sid}/Messages.json"
      data.Body = response.data
    else if interactionType is "ivr"
      url = "https://api.twilio.com/2010-04-01/Accounts/#{sid}/Calls.json"
      #data.Url = "#{Jackfruit.gooseberryEndpoint}?message=Start #{@questionSetName}"
      data.Url = Jackfruit.gooseberryEndpoint
      ###
      data.Twiml = "
        <Response>
          <Say>
            #{response.data}
          </Say>
        </Response>
      "
      ###

    await axios.post url, qs.stringify(data), auth:
      username: sid
      password: token

module.exports = Initiator
