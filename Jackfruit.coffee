Backbone = require 'backbone'
global.$ = require 'jquery'
Backbone.$  = $
global.Cookie = require 'js-cookie'
global.moment = require 'moment'
global._ = require 'underscore'
Encryptor = require('simple-encryptor')

global.PouchDB = require('pouchdb-core')
PouchDB
  .plugin(require 'pouchdb-adapter-http')
  .plugin(require 'pouchdb-adapter-idb')
  .plugin(require 'pouchdb-mapreduce')
  .plugin(require 'pouchdb-replication')
  .plugin(require 'pouchdb-upsert')

{ CognitoIdentityClient } = require("@aws-sdk/client-cognito-identity")
{ fromCognitoIdentityPool } = require("@aws-sdk/credential-provider-cognito-identity")
{ DynamoDBClient } = require("@aws-sdk/client-dynamodb")
{ PutItemCommand, GetItemCommand, ScanCommand } = require("@aws-sdk/client-dynamodb")
{ marshall, unmarshall } = require("@aws-sdk/util-dynamodb")

Router = require './Router'


global.Jackfruit =
  knownDatabaseServers:
    Zanzibar: "https://zanzibar.cococloud.co"
    Kigelia: "https://kigelia.cococloud.co"
    Ceshhar: "https://ceshhar.cococloud.co"
    Keep: "https://keep.cococloud.co"
    Local: "http://localhost:5984"
    Tusome22340:
      region: "us-east-1"
      EncryptedIdentityPoolId: '41d30953e2420e2c8af62881a82617ada228e9a809847879a9ee9fc34fafa5cd54ecfea4eb912295b9053549023e3bd1H7gVNDJxH0SO3zAerZ+2G7Fj3PcOLXZCF2eDiflmFic8netSzdmB9pG4dZrxhqySi7qFSaxBAqNXEzp6QDesNA=='
  gooseberryEndpoint: "https://qegqsa53znvkq5pqp4kig2andi0jjtso.lambda-url.us-east-1.on.aws/"

Jackfruit.serverCredentials = {}
for name, url of Jackfruit.knownDatabaseServers
  credentials = Cookie.get("#{name}-credentials")
  Jackfruit.serverCredentials[name] = credentials if credentials



## GLOBAL FUNCTIONS ##
#
Jackfruit.canCreateDesignDoc = =>
  Jackfruit.database.put {_id:"_design/test"}
  .then (result) =>
    Jackfruit.database.remove 
      _id: result.id
      _rev: result.rev
    Promise.resolve(true)
  .catch (error) => 
    if error.status is 403
      Promise.resolve(false)


Jackfruit.setupDatabase = (serverName, databaseOrGatewayName) =>
  Jackfruit.serverName = serverName

  if Jackfruit.knownDatabaseServers[Jackfruit.serverName].EncryptedIdentityPoolId # DynamoDB
    Jackfruit.database = null

    unless Jackfruit.dynamoDBClient?
      # This is encrypted with the tool in the scripts directory
      password = Cookie.get("password") or prompt("Password for Jackfruit serverName:")
      decryptedIdentityPoolId = Encryptor(password+password+password).decrypt(Jackfruit.knownDatabaseServers[Jackfruit.serverName].EncryptedIdentityPoolId)?[0]

      unless decryptedIdentityPoolId?.match(/:/) # Looks like an IdentityPoolId
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

    Jackfruit.updateGateway(databaseOrGatewayName)

  else
    Jackfruit.dynamoDBClient = null
    username = Cookie.get("username")
    password = Cookie.get("password")
    unless username and password
      console.log "CHANGING"
      Jackfruit.targetUrl = document.location.hash.replace(/#/,"")
      return router.navigate "server/#{Jackfruit.serverName}", trigger:true
    serverUrlWithCredentials = "#{Jackfruit.knownDatabaseServers[serverName]}".replace(/:\/\//, "://#{username}:#{password}@")
    Jackfruit.database = new PouchDB("#{serverUrlWithCredentials}/#{databaseOrGatewayName}")
    Jackfruit.databaseName = databaseOrGatewayName
    Jackfruit.databasePlugins = await Jackfruit.database.allDocs
      startkey: "_design/plugin-"
      endkey: "_design/plugin-\uf000"
      include_docs: true
    .then (result) =>
      Promise.resolve(_(result?.rows).pluck "doc")

Jackfruit.updateCurrentGateway = =>
  Jackfruit.updateGateway(Jackfruit.gateway.gatewayName)

Jackfruit.updateGateway = (gatewayName) =>
  result = await Jackfruit.dynamoDBClient.send(
    new GetItemCommand(
      TableName: "Configurations"
      Key: 
        gatewayName:
          "S": gatewayName
    )
  )
  Jackfruit.gateway = unmarshall(result.Item)

Jackfruit.updateQuestionSetForCurrentGateway = (questionSet, options) =>
  await Jackfruit.updateCurrentGateway()
  Jackfruit.updateQuestionSetForGateway(questionSet, options, Jackfruit.gateway)

Jackfruit.updateQuestionSetForGateway = (questionSet, options, gateway) =>
  gateway["Question Sets"][questionSet.label] = questionSet
  if options?.delete is true
    delete gateway["Question Sets"][questionSet.label]

  Jackfruit.dynamoDBClient.send(
    new PutItemCommand(
      TableName: "Configurations"
      Item: marshall(gateway)
    )
  )



Jackfruit.fetchDatabaseList = =>
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

global.router = new Router()
Backbone.history.start()
