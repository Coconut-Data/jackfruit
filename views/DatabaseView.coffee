Backbone = require 'backbone'

class DatabaseView extends Backbone.View
  render: =>
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
        <h1>#{@databaseName}</h1>
        <h2>Select a question set</h2>
        <div id='questions'/>
        <h2>Create a new question set</h2>
        <div>
          <input id='newQuestionSet'/>
          <button id='create'>Create</button>
        </div>
      "
      @$("#questions").html (for row in result.rows
        "<li><a href='#questionSet/#{@serverName}/#{@databaseName}/#{row.id}'>#{row.id}</a></li>"
      ).join("")

  events: =>
    "click #create": "newQuestionSet"

  newQuestionSet: =>
    newQuestionSetName = @$("#newQuestionSet").val()
    Jackfruit.database.put
      _id: newQuestionSetName
      collection: "question"
      questions: []
    .then =>
      router.navigate "questionSet/#{newQuestionSetName}", {trigger: true}


module.exports = DatabaseView
