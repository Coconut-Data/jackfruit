Backbone = require 'backbone'
Passphrase = require 'xkcd-passphrase'

crypto = require('crypto')

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
        <h1>Select a database:</h1>
        #{
          (for database in databaseList
            continue if database.startsWith("_")
            continue if database.match(/backup/)
            continue if database.startsWith("plugin")
            "<li style='height:50px;'><a href='#database/#{Jackfruit.serverName}/#{database}'>#{database}</a></li>"
          ).join("")
        }
        <h1>Create a new database:</h1>
        Database Name: <input id='databaseName'></input>
        <br/>
        <button id='newDatabase'>Create</button>
      "

  renderLoginForm: =>
    @$el.html "
      <h1>#{Jackfruit.serverName}</h1>
      <div style='margin-left:100px; margin-top:100px; id='usernamePassword'>
        <div>
          Username: <input id='username'/>
        </div>
        <div>
          Password: <input type='password' id='password'/>
        </div>
        <button id='login'>Login</button>
      </div>
    "

  events: =>
    "click #login": "updateUsernamePassword"
    "click #newDatabase": "newDatabase"

  newDatabase: =>
    username = Cookie.get("username")
    password = Cookie.get("password")
    Jackfruit.databaseName = @$("#databaseName").val()
    newUser = await Passphrase.generateWithWordCount(1)
    newPassword = await Passphrase.generateWithWordCount(1)

    alert "Creating user: #{newUser} with password: #{newPassword} as the initial user. (You will need this to login)"

    serverUrlWithCredentials = "#{Jackfruit.knownDatabaseServers[Jackfruit.serverName]}".replace(/:\/\//, "://#{username}:#{password}@")
    console.log "#{serverUrlWithCredentials}/#{Jackfruit.databaseName}"
    Jackfruit.database = new PouchDB("#{serverUrlWithCredentials}/#{Jackfruit.databaseName}")

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
    @render()

  login: =>
    @username = Cookie.get("username")
    @password = Cookie.get("password")

    unless @username and @password
      Promise.reject()

    @fetchDatabaseList()

  fetchDatabaseList: =>
    new Promise (resolve,reject) =>
      #fetch "#{Jackfruit.knownDatabaseServers[Jackfruit.serverName]}/_all_dbs",
      console.log @username
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
