Backbone = require 'backbone'

class DefaultView extends Backbone.View

  render: =>
    if Jackfruit.database
      @selectOrAddQuestion()
    else
      @selectApplication()

  events: =>
    "button click": "openQuestionSet"
    "click #login": "login"
    "change input#application": "setApplication"
    "click #create": "newQuestionSet"

  newQuestionSet: =>
    newQuestionSetName = @$("#newQuestionSet").val()
    Jackfruit.database.put
      _id: newQuestionSetName
      collection: "question"
      questions: []
    .then =>
      router.navigate "#{Jackfruit.application}/questionSet/#{newQuestionSetName}", {trigger: true}


  confirmLogin: =>
    @$el.html "Loading"
    @target.username = Cookie.get("username")
    @target.password = Cookie.get("password")
    @questionSet = new QuestionSet(@target)
    @questionSet.fetch()
    .catch (error) =>
      if error.name is "not_found"
        alert("Can't find database: #{@questionSet.databaseUrl}")
        throw error
      if error.name is "unauthorized"
        @$el.html @loginForm()
        throw "Waiting for username password to proceed"
    .then =>
      @render()

  selectOrAddQuestion: =>
    Jackfruit.database.query "questions"
    .catch (error) =>
      if error.name is "not_found"
        console.log "Creating design doc for questions query"
        Jackfruit.database.put
          _id: '_design/questions',
          language: "coffeescript",
          views:
            questions:
              "map": "(doc) ->\n  if doc.collection and doc.collection is \"question\"\n    emit doc.id\n"
        .catch (error) =>
          @getUsernamePassword()
          console.log error
          throw "Invalid Username/Password"
        .then =>
          @selectOrAddQuestion()
    .then (result) =>
      @$el.html "
        <h1>Question Sets for #{Jackfruit.application}</h1>
        <div id='questions'/>
        <div>
          Create New Question Set: <input id='newQuestionSet'/>
          <button id='create'>Create</button>
        </div>
      "
      @$("#questions").html (for row in result.rows
        "<ul><a href='##{Jackfruit.application}/questionSet/#{row.id}'>#{row.id}</a></ul>"
      ).join("")

  selectApplication: =>
    @applications =
      "Ceshhar": "http://ceshhar.cococloud.co/ceshhar"
      "Coconut Surveillance": "https://zanzibar.cococloud.co/zanzibar"
      "Shokishoki": "https://zanzibar.cococloud.co/shokishoki"
      "Local Shokishoki": "http://localhost:5984/shokishoki"

    @$el.html "
      <div>
        Select a Coconut Application (or enter your own)
        <input id='application' list='applications'>
        <datalist id='applications'>
          #{
            (for application of @applications
              "<option value='#{application}'>"
            ).join("")
          }
        </datalist>
      </div>
      <div style='display:none' id='usernamePassword'>
        Invalid Username and or Password:
        <div>
          Username: <input id='username'/>
        </div>
        <div>
          <input type='password' id='password'/>
        </div>
        <button id='login'>Login</button>
      </div>
    "
  setApplicationName: (applicationName) =>
    @$("#application").val(applicationName)
    @setApplication()

  setApplication: () =>
    router.setupDatabase(@$("#application").val())
    .then => # Login successful
      router.navigate("application/#{Jackfruit.application}")
      Jackfruit.database = database
      @render()
    .catch =>
      @getUsernamePassword()

  getUsernamePassword: =>
    @$("#usernamePassword").show()

  login: =>
    @$("#usernamePassword").hide()
    Cookie.set "username", @$("#username").val()
    Cookie.set "password", @$("#password").val()
    @setApplication()

module.exports = DefaultView
