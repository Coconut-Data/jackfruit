Backbone = require 'backbone'
UsersView = require './UsersView'

class DatabaseView extends Backbone.View
  render: =>
    @$el.html "<h1>Loading question sets...</h1>"
    Jackfruit.database.query "questions"
    .catch (error) =>
      if error.name is "not_found"
        @$el.html "<h1>Creating questions design doc, please wait...</h1>>"
        Jackfruit.database.put
          _id: '_design/questions',
          language: "coffeescript",
          views:
            questions:
              "map": "(doc) ->\n  if doc.collection and doc.collection is \"question\"\n    emit doc._id\n"
        .catch (error) =>
          return alert error
        .then =>
          @render()
    .then (result) =>
      @$el.html "
        <style>
          li {
            padding-top: 2em;
          }
          li a{
            font-size: 2em;
          }
        </style>
        <h1>#{@databaseName}</h1>
        <h2>Select a question set</h2>
        <div id='questions'/>
        <h2>Create a new question set</h2>
        <div>
          <input id='newQuestionSet'/>
          <button id='create'>Create</button>
        </div>

        <h2>Active Plugins</h2>
        <div id='activePlugins'></div>

        <h2>Add A Plugin</h2>
        <div id='addPlugin'></div>

        <h2>Users</h2>
        <div id='users'></div>

      "
      @$("#questions").html (for row in result.rows
        "<li><a href='#questionSet/#{@serverName}/#{@databaseName}/#{row.id}'>#{row.id}</a></li>"
      ).join("")

      @loadPluginData()

      @usersView = new UsersView()
      @usersView.setElement @$("#users")
      @usersView.render()


  loadPluginData: =>
    availablePlugins = (await @fetchDatabaseList())
      .filter (database) => database.match(/^plugin/)
      .map (plugin) => plugin.replace(/plugin-/,"")

    loadedPlugins = []

    await Jackfruit.database.allDocs
      startkey: "_design/plugin"
      endkey: "_design/plugin\ufff0"
    .then (result) =>
      console.log result
      loadedPlugins = for plugin in result.rows
        plugin.id.replace(/.*\/plugin-/, "").replace("#{@databaseName}-","")

      for plugin in loadedPlugins
        @$("#activePlugins").append "
          <li>#{plugin} <button class='updatePlugin' data-plugin='#{plugin}'>Update</button></li>
        "

    @$("#addPlugin").html "
      <select id='selectPlugin'>
        <option></option>
        #{
          for plugin in _(availablePlugins).difference(loadedPlugins)
            "<option>#{plugin}</option>"
        }
      </select>
    "

  events: =>
    "click #create": "newQuestionSet"
    "change #selectPlugin": "addPlugin"
    "click .updatePlugin": "updatePlugin"

  updatePlugin: (event) =>
    if name = event.target.getAttribute("data-plugin")
      databasePath = Jackfruit.database.name.replace(/\/([^\/]+)$/,"/plugin-#{name}")
      pluginDatabase = new PouchDB(databasePath)
      config = await pluginDatabase.get "plugin-config"
      nameOfPluginDoc = "plugin-#{@databaseName}-#{name}"
      return unless confirm "Are you sure you want to update #{nameOfPluginDoc} from #{name}?"
      nameOfPluginDoc = "_design/#{nameOfPluginDoc}"

      # Upsert didn't work, so do it manually - just insert the current rev
      await Jackfruit.database.put
        _id: nameOfPluginDoc
        _rev: (await Jackfruit.database.get(nameOfPluginDoc))?._rev
        source: config.sourceDatabase
        doc_ids: config.doc_ids
        jackfruit: config.jackfruit
        _attachments: (await pluginDatabase.get("attachments", attachments: true ))._attachments

  addPlugin: (event) =>
    if name = event.target.selectedOptions?[0]?.innerText
      return unless confirm "Are you sure you want to add #{name}"
      databasePath = Jackfruit.database.name.replace(/\/([^\/]+)$/,"/plugin-#{name}")
      pluginDatabase = new PouchDB(databasePath)
      config = await pluginDatabase.get "plugin-config"
      nameForPlugin = "plugin-#{@databaseName}-#{name}"

      console.log await pluginDatabase.get("attachments", attachments: true )

      await Jackfruit.database.put {
        _id: "_design/#{nameForPlugin}" 
        source: config.sourceDatabase
        doc_ids: config.doc_ids
        jackfruit: config.jackfruit
        _attachments: (await pluginDatabase.get("attachments", attachments: true ))._attachments
      }
      @render()

  newQuestionSet: =>
    newQuestionSetName = @$("#newQuestionSet").val()
    Jackfruit.database.put
      _id: newQuestionSetName
      collection: "question"
      questions: []
    .then =>
      router.navigate "questionSet/#{@serverName}/#{@databaseName}/#{newQuestionSetName}", {trigger: true}

  fetchDatabaseList: =>
    @username = Cookie.get("username")
    @password = Cookie.get("password")
    new Promise (resolve,reject) =>
      #fetch "#{Jackfruit.knownDatabaseServers[Jackfruit.serverName]}/_all_dbs",
      fetch "#{Jackfruit.knownDatabaseServers[@serverName]}/_all_dbs",
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
module.exports = DatabaseView
