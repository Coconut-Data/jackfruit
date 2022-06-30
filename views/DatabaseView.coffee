Backbone = require 'backbone'
global.UsersView = require './UsersView'
JsonDiffPatch = require 'jsondiffpatch'

hljs = require 'highlight.js/lib/highlight';
coffeescriptHighlight = require 'highlight.js/lib/languages/coffeescript';
hljs.registerLanguage('coffeescript', coffeescriptHighlight);

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
          #{@jsonDiffCss()}
        </style>
        <h1>#{@databaseName}</h1>
        <h2>Select a question set</h2>
        <div id='questions'></div>
        <br/>
        <br/>
        #{
          if Jackfruit.databaseName.match(/develop/) 
            "
            <button id='updateFromProduction'>Update All Question Sets from Production</button>
            <button id='deploy'>Deploy to Production</button>
            <button id='showDiff'>Show differences with Production</button>
            <div id='diff'></div>
            "
          else
            ""
        }

        <br/>
        <br/>
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

        <h2>Configuration</h2>
        <div id='configuration'>
          #{
            configuration = JSON.stringify(await Jackfruit.database.get("JackfruitConfig").catch (error) => Promise.resolve "")
          }
          <pre style=''><code class='toggleToEdit'>#{configuration}</code></pre>
          <div class='codeEditor'>
            <textarea id='JackfruitConfig' style='display:block' class='code'>#{configuration}</textarea>
            <button class='save'>Save</button>
            <button class='cancel'>Cancel</button>
          </div>
        </div>

      "
      @questionSets = []
      @$("#questions").html (for row in result.rows
        @questionSets.push row.id
        "
        <li>
          <a href='#questionSet/#{@serverName}/#{@databaseName}/#{row.id}'>#{row.id}</a> 
          <button class='copy' data-question='#{row.id}'>Copy</button> 
          <button class='rename' data-question='#{row.id}'>Rename</button> 
          #{
            if Jackfruit.canCreateDesignDoc()
              "
              <button class='remove' data-question='#{row.id}'>Remove</button> 
              "
            else
              ""
          }
        </li>
        "
      ).join("")

      @loadPluginData()

      @usersView = new UsersView()
      @usersView.setElement @$("#users")
      @usersView.render()

      unless await Jackfruit.canCreateDesignDoc()
        @$("#activePlugins").before "Plugins can only be changed by administrators"

      hljs.configure
        languages: ["coffeescript", "json"]
        useBR: false

      @$('pre code').each (i, snippet) =>
        hljs.highlightBlock(snippet);


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
    "click .copy": "copy"
    "click .rename": "rename"
    "click .remove": "remove"
    "click #updateFromProduction": "updateFromProduction"
    "click #showDiff": "showDiff"
    "click #deploy": "deploy"
    "click button.save": "save"

  save: =>
    await Jackfruit.database.put JSON.parse(@$("#JackfruitConfig").val())
    .catch (error) => alert error
    @render()


  showDiff: =>
    @$("#diff").html "<h2>Loading differences, please wait...</h2>"
    messages = ""
    production = new PouchDB(Jackfruit.database.name.replace("-development", ""))
    questionSets = for questionSetId in @questionSets
      developmentDatabase = await Jackfruit.database.get(questionSetId)
      productionDatabase = await production.get(questionSetId)
        .catch (error) => Promise.resolve null
      [developmentDatabase, productionDatabase]


    @$("#diff").html ""

    for questionSetPair in questionSets
      [developmentVersion, productionVersion] = questionSetPair
      if productionVersion is null
        @$("#diff").append "<hr>Production is MISSING #{developmentVersion._id}<br/>"
      else
        if JSON.stringify(developmentVersion.questions) isnt JSON.stringify(productionVersion.questions)
          delta = JsonDiffPatch.create(
            objectHash: (obj, index) =>
              obj.label
          ).diff(productionVersion.questions, developmentVersion.questions)

          @$("#diff").append "<hr/>

            <a href='#questionSet/#{@serverName}/#{@databaseName}/#{developmentVersion._id}'>#{developmentVersion._id}</a><br/>
            #{
              JsonDiffPatch.formatters.html.format(delta, developmentVersion.questions)
            }
          "
          JsonDiffPatch.formatters.html.hideUnchanged()




  updateFromProduction: =>
    source = new PouchDB(prompt("Source URL (e.g. https://username:password@example.com/foo)?"))
    for questionSetId in @questionSets
      questionSet = await QuestionSet.fetch(questionSetId)
      doc = await source.get questionSet.name()
      if doc and confirm "Are you sure you want to update #{questionSet.name()} from #{source.name} to #{await Jackfruit.database.name}? This will lose any changes you may have made to #{Jackfruit.database.name} in development."
        $("#content").html "<br/><br/>Updating #{questionSet.name()} from #{source.name}... development"
        await Jackfruit.database.remove(questionSet.data)
        delete doc._rev
        await Jackfruit.database.put doc

    $("#content").html "<br/><br/>Finished, refreshing in 1 second."
    _.delay =>
      document.location.reload()
    , 1000

  deploy: =>
    target = new PouchDB(prompt("Target URL (e.g. https://username:password@example.com/foo)?"))
    if target isnt "" and confirm "Are you sure you want to deploy #{@questionSets.join(", ")} to #{target}? Have you reviewed the differences?"
        Jackfruit.database.replicate.to target,
          doc_ids: @questionSets
        .on "error", => alert error
        .on "complete", => alert JSON.stringify(result)
        .on "denied", => alert "Denied - wrong authentication?"
        .on "change", (change) => console.log change

  copy: (event, renderOnDone = true) =>
    question = event.target.getAttribute("data-question")
    questionDoc = await Jackfruit.database.get question
    delete questionDoc._rev
    questionDoc._id = prompt("Name: ")
    if questionDoc._id is question or questionDoc._id is ""
      alert "Name must be different and not empty"
      return null
    console.log questionDoc
    await Jackfruit.database.put questionDoc
    @render() if renderOnDone

  rename: (event) =>
    unless await(@copy(event, false)) is false #only remove if copy succeeds!
      await @remove(event, false)
      @render()

  remove: (event, promptToDelete = true, renderOnDone = true) =>
    question = event.target.getAttribute("data-question")
    if not promptToDelete or confirm "Are you sure you want to remove #{question}?"
      if not promptToDelete or prompt("Confirm the name of question that you want to remove:") is question
        questionDoc = await Jackfruit.database.get question
        await Jackfruit.database.remove questionDoc
        @render() if renderOnDone

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
      .catch (error) => 
        alert "Error while updating: #{JSON.stringify error}"
        return
      alert "#{nameOfPluginDoc} Updated"

      @render()

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


  jsonDiffCss: => "
.jsondiffpatch-delta{font-family:'Bitstream Vera Sans Mono','DejaVu Sans Mono',Monaco,Courier,monospace;font-size:12px;margin:0;padding:0 0 0 12px;display:inline-block}.jsondiffpatch-delta pre{font-family:'Bitstream Vera Sans Mono','DejaVu Sans Mono',Monaco,Courier,monospace;font-size:12px;margin:0;padding:0;display:inline-block}ul.jsondiffpatch-delta{list-style-type:none;padding:0 0 0 20px;margin:0}.jsondiffpatch-delta ul{list-style-type:none;padding:0 0 0 20px;margin:0}.jsondiffpatch-added .jsondiffpatch-property-name,.jsondiffpatch-added .jsondiffpatch-value pre,.jsondiffpatch-modified .jsondiffpatch-right-value pre,.jsondiffpatch-textdiff-added{background:#bfb}.jsondiffpatch-deleted .jsondiffpatch-property-name,.jsondiffpatch-deleted pre,.jsondiffpatch-modified .jsondiffpatch-left-value pre,.jsondiffpatch-textdiff-deleted{background:#fbb;text-decoration:line-through}.jsondiffpatch-unchanged,.jsondiffpatch-movedestination{color:gray;display:none}.jsondiffpatch-unchanged,.jsondiffpatch-movedestination>.jsondiffpatch-value{transition:all .5s;-webkit-transition:all .5s;overflow-y:hidden}.jsondiffpatch-unchanged-showing .jsondiffpatch-unchanged,.jsondiffpatch-unchanged-showing .jsondiffpatch-movedestination>.jsondiffpatch-value{max-height:100px}.jsondiffpatch-unchanged-hidden .jsondiffpatch-unchanged,.jsondiffpatch-unchanged-hidden .jsondiffpatch-movedestination>.jsondiffpatch-value{max-height:0}.jsondiffpatch-unchanged-hiding .jsondiffpatch-movedestination>.jsondiffpatch-value,.jsondiffpatch-unchanged-hidden .jsondiffpatch-movedestination>.jsondiffpatch-value{display:block}.jsondiffpatch-unchanged-visible .jsondiffpatch-unchanged,.jsondiffpatch-unchanged-visible .jsondiffpatch-movedestination>.jsondiffpatch-value{max-height:100px}.jsondiffpatch-unchanged-hiding .jsondiffpatch-unchanged,.jsondiffpatch-unchanged-hiding .jsondiffpatch-movedestination>.jsondiffpatch-value{max-height:0}.jsondiffpatch-unchanged-showing .jsondiffpatch-arrow,.jsondiffpatch-unchanged-hiding .jsondiffpatch-arrow{display:none}.jsondiffpatch-value{display:inline-block}.jsondiffpatch-property-name{display:inline-block;padding-right:5px;vertical-align:top}.jsondiffpatch-property-name:after{content:': '}.jsondiffpatch-child-node-type-array>.jsondiffpatch-property-name:after{content:': ['}.jsondiffpatch-child-node-type-array:after{content:'],'}div.jsondiffpatch-child-node-type-array:before{content:'['}div.jsondiffpatch-child-node-type-array:after{content:']'}.jsondiffpatch-child-node-type-object>.jsondiffpatch-property-name:after{content:': {'}.jsondiffpatch-child-node-type-object:after{content:'},'}div.jsondiffpatch-child-node-type-object:before{content:'{'}div.jsondiffpatch-child-node-type-object:after{content:'}'}.jsondiffpatch-value pre:after{content:','}li:last-child>.jsondiffpatch-value pre:after,.jsondiffpatch-modified>.jsondiffpatch-left-value pre:after{content:''}.jsondiffpatch-modified .jsondiffpatch-value{display:inline-block}.jsondiffpatch-modified .jsondiffpatch-right-value{margin-left:5px}.jsondiffpatch-moved .jsondiffpatch-value{display:none}.jsondiffpatch-moved .jsondiffpatch-moved-destination{display:inline-block;background:#ffb;color:#888}.jsondiffpatch-moved .jsondiffpatch-moved-destination:before{content:' => '}ul.jsondiffpatch-textdiff{padding:0}.jsondiffpatch-textdiff-location{color:#bbb;display:inline-block;min-width:60px}.jsondiffpatch-textdiff-line{display:inline-block}.jsondiffpatch-textdiff-line-number:after{content:','}.jsondiffpatch-error{background:red;color:white;font-weight:bold}
  "
module.exports = DatabaseView
