Backbone = require 'backbone'
Passphrase = require 'xkcd-passphrase'
Encryptor = require('simple-encryptor')

crypto = require('crypto')

{ CognitoIdentityClient } = require("@aws-sdk/client-cognito-identity")
{ fromCognitoIdentityPool } = require("@aws-sdk/credential-provider-cognito-identity")
{DynamoDBClient,ScanCommand,PutItemCommand, CreateTableCommand, DescribeTableCommand} = require("@aws-sdk/client-dynamodb")
{ marshall, unmarshall } = require("@aws-sdk/util-dynamodb")

class ServerView extends Backbone.View

  render: =>
    @login()
    .catch =>
      return @renderLoginForm()
    .then (databaseList) =>

      @$el.html "
        <style>
          li {
            padding-top: 2em;
          }
          li a{
            font-size: 2em;
          }
        </style>
        <h1>Select a #{if @isDynamoDB then "Gateway" else "database"}:</h1>
        #{
        }

        #{
          if @isDynamoDB

            "
              #{
                (for gateway in databaseList
                  "<li style='height:50px;'><a href='#gateway/#{Jackfruit.serverName}/#{gateway}'>#{gateway}</a></li>"
                ).join("")
              
              }
              <h1>Create a new gateway:</h1>
              Gateway Name: <input id='gatewayName'></input>
              <br/>
              <button id='newGateway'>Create</button>
            "

          else
            @taskDatabase = new PouchDB("#{@getServerUrlWithCredentials()}/server_tasks")
            databaseList = (for database in databaseList
              continue if database.startsWith("_")
              continue if database.match(/backup/)
              continue if database.startsWith("plugin")
              "<li style='height:50px;'><a href='#database/#{Jackfruit.serverName}/#{database}'>#{database}</a></li>"
            ).join("")

            "
              #{databaseList}
              <h1>Create a new database:</h1>
              Database Name: <input id='databaseName'></input>
              <br/>
              <button id='newDatabase'>Create</button>

              <h2>Every Day At Midnight</h2>
              <textarea id='daily'>
              #{
                await @taskDatabase.get "daily"
                .then (doc) => Promise.resolve doc.code
                .catch (error) => Promise.resolve("")
              }
              </textarea>
              <button id='daily-button''>Update</button>

              <h2>Every 5 Minutes</h2>
              <textarea id='five-minutes'>
              #{
                await @taskDatabase.get "five-minutes"
                .then (doc) => Promise.resolve doc.code
                .catch (error) => Promise.resolve("")
              }
              </textarea>
              <button id='five-minutes-button''>Update</button>
            "
        }
      "


  renderLoginForm: =>
    @$el.html "
      <h1>#{Jackfruit.serverName}</h1>
      <div style='margin-left:100px; margin-top:100px; id='usernamePassword'>
        <div id='usernameDiv'>
          Username: <input id='username'/>
        </div>
        <div>
          Password: <input type='password' id='password'/>
        </div>
        <button id='login'>Login</button>
      </div>
    "

    if Jackfruit.knownDatabaseServers[Jackfruit.serverName].EncryptedIdentityPoolId # DynamoDB
      @$("#usernameDiv").hide()

  events: =>
    "click #login": "updateUsernamePassword"
    "click #newDatabase": "newDatabase"
    "click #newGateway": "newGateway"
    "click #daily-button": "updateTasks"
    "click #five-minutes-button": "updateTasks"

  updateTasks: (event) =>
    dailyOrFiveMinutes = event.target.getAttribute("id")?.replace(/-button/,"")
    await @taskDatabase.upsert dailyOrFiveMinutes, =>
      _id: dailyOrFiveMinutes
      code: @$("##{dailyOrFiveMinutes}").val()
    @render()

  getServerUrlWithCredentials: =>
    username = Cookie.get("username")
    password = Cookie.get("password")
    "#{Jackfruit.knownDatabaseServers[Jackfruit.serverName]}".replace(/:\/\//, "://#{username}:#{password}@")

  newGateway: =>
    gatewayName = @$("#gatewayName").val()
    item =
      gatewayName: gatewayName
      "Question Sets":
        "Test Questions": 
          label: "Test Questions"
          version: "1"
          questions: [
            {
              label: "Name"
              calculated_label: "What is your name?"
              type: "text"
            }
            {
              label: "Middle Name"
              calculated_label: "\#{ResultOfQuestion('Name')}, What is your middle name?"
              skip_logic: "ResultOfQuestion('First Name') is 'Pete'"
              type: "text"
            }
          ]
    await @dynamoDBClient.send(
      new PutItemCommand(
        TableName: "Configurations"
        Item: marshall(item)
      )
    )
    await @dynamoDBClient.send(
      new CreateTableCommand(
        TableName: "Gateway-#{gatewayName}"
        AttributeDefinitions: [
          {
            AttributeName: "lastUpdate"
            AttributeType: "N"
          },
          {
            AttributeName: "questionSetName"
            AttributeType: "S"
          },
          {
            AttributeName: "source"
            AttributeType: "S"
          },
          {
            AttributeName: "startTime"
            AttributeType: "N"
          }
        ]
        KeySchema: [
          {
            AttributeName: "source"
            KeyType: "HASH"
          },
          {
            AttributeName: "startTime",
            KeyType: "RANGE"
          }
        ]
        BillingMode: "PAY_PER_REQUEST"
        GlobalSecondaryIndexes:[
          IndexName: "resultsByQuestionSetAndUpdateTime"
          KeySchema: [
            {
              AttributeName: "questionSetName",
              KeyType: "HASH"
            },
            {
              AttributeName: "lastUpdate",
              KeyType: "RANGE"
            }
          ]
          Projection:
            NonKeyAttributes: ["reporting" ]
            ProjectionType: "INCLUDE"
        ]
      )
    )
    @render()


  newDatabase: =>
    newUser = await Passphrase.generateWithWordCount(1)
    newPassword = await Passphrase.generateWithWordCount(1)
    alert "Creating user: #{newUser} with password: #{newPassword} as the initial user. (You will need this to login)"

    Jackfruit.databaseName = @$("#databaseName").val()
    Jackfruit.database = new PouchDB("#{@getServerUrlWithCredentials()}/#{Jackfruit.databaseName}")

    await Jackfruit.database.bulkDocs [
      {
        _id: "client encryption key"
        key: await Passphrase.generate()
      }
      {
        _id: '_design/questions',
        language: "coffeescript",
        views:
          questions:
            map: "(doc) ->\n  if doc.collection and doc.collection is \"question\"\n    emit doc._id\n"
      }
      {
        _id: "_design/docIDsForUpdating",
        language: "coffeescript",
        views:
          docIDsForUpdating:
            map: "(doc) ->\n  emit(doc._id, null) if doc.collection is \"user\" or doc.collection is \"question\"\n  emit(doc._id, null) if doc.isApplicationDoc is true\n"
      }
      {
        _id: "user.#{newUser}"
        password: (crypto.pbkdf2Sync newPassword, "", 1000, 256/8, 'sha256').toString('base64')
        isApplicationDoc: true,
        comments: "Test user",
        roles: [
          "admin"
        ],
        collection: "user",
      }

    ]
    .catch (error) => 
      console.error error
      alert JSON.stringify error

    router.navigate "database/#{Jackfruit.serverName}/#{Jackfruit.databaseName}", trigger:true



  updateUsernamePassword: =>
    Cookie.set "username", @$('#username').val()
    Cookie.set "password", @$('#password').val()

    if Jackfruit.targetUrl
      targetUrl = Jackfruit.targetUrl
      Jackfruit.targetUrl = null
      return router.navigate targetUrl, trigger:true

    @render()

  login: =>
    @username = Cookie.get("username")
    @password = Cookie.get("password")

    unless @password
      return Promise.reject()

    @fetchDatabaseList()

  fetchDatabaseList: =>
    new Promise (resolve,reject) =>

      if Jackfruit.knownDatabaseServers[Jackfruit.serverName].EncryptedIdentityPoolId # DynamoDB
        @isDynamoDB = true

        unless Jackfruit.dynamoDBClient
          # This is encrypted with the tool in the scripts directory
          password = Cookie.get("password") or prompt("Password for Jackfruit serverName:")
          decryptedIdentityPoolId = Encryptor(password+password+password).decrypt(Jackfruit.knownDatabaseServers[Jackfruit.serverName].EncryptedIdentityPoolId)?[0]

          unless decryptedIdentityPoolId?.match(/:/) # Looks like an IdentityPoolId
            if password isnt ""
              alert "Password is not correct. Your password was: #{password}"
            Cookie.set("password", "")
            document.location.reload()

          if decryptedIdentityPoolId?.match(/:/) # Looks like an IdentityPoolId
            Jackfruit.knownDatabaseServers[Jackfruit.serverName].IdentityPoolId = decryptedIdentityPoolId
            Cookie.set("password",password)

            region = Jackfruit.knownDatabaseServers[Jackfruit.serverName].region
            Jackfruit.dynamoDBClient = new DynamoDBClient(
              region: region
              credentials: fromCognitoIdentityPool(
                client: new CognitoIdentityClient({region})
                identityPoolId: decryptedIdentityPoolId
              )
            )





        gatewayConfigurations = await Jackfruit.dynamoDBClient.send(
          new ScanCommand(
            TableName: "Configurations"
          )
        )

        Jackfruit.gateways = {}

        for item in gatewayConfigurations.Items
          unmarshalledItem = unmarshall(item)
          Jackfruit.gateways[unmarshalledItem.gatewayName] = unmarshalledItem

        resolve(gatewayName for gatewayName,details of Jackfruit.gateways)

      else
        @isDynamoDB = false
        fetch "#{Jackfruit.knownDatabaseServers[Jackfruit.serverName]}/_all_dbs",
          method: 'GET'
          credentials: 'include'
          headers:
            'content-type': 'application/json'
            authorization: "Basic #{btoa("#{@username}:#{@password}")}"
        .catch (error) =>
          reject(error)
        .then (response) =>
          if response.status is 401
            reject(response.statusText)
          else
            result = await response.json()
            resolve(result)

module.exports = ServerView
