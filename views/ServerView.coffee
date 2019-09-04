Backbone = require 'backbone'

class ServerView extends Backbone.View

  render: =>

    @login()
    .catch =>
      return @renderLoginForm()
    .then (databaseList) =>

      @$el.html "
        <h1>Select a database:</h1>
        #{
          (for database in databaseList
            continue if database.startsWith("_")
            "<li style='height:50px;'><a href='#database/#{Jackfruit.serverName}/#{database}'>#{database}</a></li>"
          ).join("")
        }
        <h1>Create a new database:</h1>
        Database Name: <input name='databaseName'></input>
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
    newDatabaseName = @$("#newDatabase").val()
    @databaseServer().db.create(newDatabaseName)
    .then =>
      router.navigate "database/#{newDatabaseName}", trigger:true
    .catch (error) => 
      alert error

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
