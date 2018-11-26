global.PouchDB = require 'pouchdb'
_ = require 'underscore'

class QuestionSet

  constructor: (@target) ->

  fetch: =>
    throw "No target defined" unless @target?
    @databaseUrl = "#{@target.httpType}://#{@target.username}:#{@target.password}@#{@target.databaseUrl}/#{@target.databaseName}"
    @database = new PouchDB(@databaseUrl, skip_setup: true)
    @database.get(@target.questionSetDocId).then (@data) =>

  save: =>
    @database.put(@data).then (response) =>
      @data._rev = response.rev
      Promise.resolve()
    .catch (error) =>
      alert "Error saving: #{JSON.stringify error}"

  name: => @data._id


QuestionSet.properties = =>
  {
    "onValidatedComplete": 
      "description":"Coffeescript code that will be executed when the entire question is marked complete and validation is passed. Useful for dictating workflow. e.g. open URL, create new result with values copied over, etc."
      "example": ""
      "data-type": "coffeescript"
    "action_on_questions_loaded":
      "description":"Coffeescript code that will be executed after the questions and their current answers are loaded."
      "data-type": "coffeescript"
    "resultSummaryFields": 
      "description": "This is used to choose which fields are shown on the question set's results page. For instance if you want the table of results to show name and date, but not ID, you could use this."
      "data-type": "object"
  }

QuestionSet.propertyList = =>
  _(QuestionSet.properties()).keys()

QuestionSet.questionProperties = =>
  {
    "action_on_change":
      "description":"Coffeescript code that will be executed after the answer to this question changes"
      "data-type": "coffeescript"
    "action_on_questions_loaded":
      "description":"Coffeescript code that will be executed after the questions and their current answers are loaded."
      "data-type": "coffeescript"
    "type":
      "description": "This is the type of question that will be displayed to the user"
      "data-type": "select"
      "options": {
        "radio":
          "description": "Allows selection from a list of choices"
        "text":
          "description": "Free text"
        "autocomplete":
          "description": "Searches for a match with whatever text has been typed to the list of autocomplete options. Also allows non matches to be entered."
        "autocomplete from previous":
          "description": "Searches for a match with whatever text has been typed to all results that have been entered for this question before. Also allows new options to be chosen."
        "label":
          "description": "No result is recorded for labels. It is a way to provide extra instructions, create sections or titles on the question set interface."
        "image":
          "description": "Displays an image." # TODO describe how this works, paths to the image, etc
        "hidden":
          "description": "Used to set data that doesn't require input from the user."
        "location":
          "description": "Will save the GPS coordinates as reported by the device."
      }
    "autocomplete-options":
      "description": "When type is autocomplete, these are the options that will be matched as the user types. Useful for selecting from a long list of options."
      "requires-type": "autocomplete"
      "data-type": "array"
    "radio-options":
      "description": "When type is radio, these are the options that will appear for the user to choose."
      "requires-type": "radio"
      "data-type": "array"
      # TODO - is there an option to allow multiple selections?
    "validation":
      "description": "Coffeescript code that will be executed when the value changed. If the result is anything but null, then validation fails, and the result is used as an error message."
      "data-type": "coffeescript"
    "skip_logic":
      "description": "Coffeescript code that will be executed every time any value in the question set changes. If the result is true, then the question will be hidden, and validation will not be required to pass in order for the answer, and therefore the entire question set to be considered valid."
      "data-type": "coffeescript"
    "required":
      "description": "Determines whether the question must be answered in order for the answer to be considered valid."
      "data-type": "select"
      "options": [
        true
        false
      ]
    "label": 
      "description": "The text for the question that will be displayed on screen"
      "data-type": "text"
      "required": true
  }

QuestionSet.questionPropertyList = =>
  _(QuestionSet.questionPropertyList()).keys()

module.exports = QuestionSet
