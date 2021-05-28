Backbone = require 'backbone'
global.$ = require 'jquery'
Backbone.$  = $
global.Cookie = require 'js-cookie'
global.moment = require 'moment'
global._ = require 'underscore'

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
    MikeAWS:
      region: "us-east-1"
      IdentityPoolId: 'us-east-1:fda4bdc9-5adc-41a0-a34e-3156f7aa6691'
  gooseberryEndpoint: "https://f9l1259lmb.execute-api.us-east-1.amazonaws.com/gooseberry"

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

  if Jackfruit.knownDatabaseServers[Jackfruit.serverName].IdentityPoolId # DynamoDB
    Jackfruit.database = null

    unless Jackfruit.dynamoDBClient?
      if Cookie.get("password") is "hungry for fruit" or prompt("Password:").toLowerCase() is "hungry for fruit"
        Cookie.set("password","hungry for fruit")


        region = Jackfruit.knownDatabaseServers[Jackfruit.serverName].region
        Jackfruit.dynamoDBClient = new DynamoDBClient(
          region: region
          credentials: fromCognitoIdentityPool(
            client: new CognitoIdentityClient({region})
            identityPoolId: Jackfruit.knownDatabaseServers[Jackfruit.serverName].IdentityPoolId
          )
        )

    Jackfruit.updateGateway(databaseOrGatewayName)

  else
    Jackfruit.dynamoDBClient = null
    username = Cookie.get("username")
    password = Cookie.get("password")
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
  Jackfruit.gateway["Question Sets"][questionSet.label] = questionSet
  if options?.delete is true
    delete Jackfruit.gateway["Question Sets"][questionSet.label]

  Jackfruit.dynamoDBClient.send(
    new PutItemCommand(
      TableName: "Configurations"
      Item: marshall(Jackfruit.gateway)
    )
  )

global.router = new Router()
Backbone.history.start()
