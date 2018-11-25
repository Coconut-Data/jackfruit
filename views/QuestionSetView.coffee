$ = require 'jquery'
Backbone = require 'backbone'
Backbone.$  = $
_ = require 'underscore'
global.Cookie = require 'js-cookie'
dasherize = require("underscore.string/dasherize")
titleize = require("underscore.string/titleize")
humanize = require("underscore.string/humanize")
slugify = require("underscore.string/slugify")

hljs = require 'highlight.js/lib/highlight';
coffeescriptHighlight = require 'highlight.js/lib/languages/coffeescript';
hljs.registerLanguage('coffeescript', coffeescriptHighlight);

global.QuestionSet = require '../models/QuestionSet'

class QuestionSetView extends Backbone.View
  events: =>
    "click #login": "login"
    "click .toggleToEdit": "edit"
    "click button.save": "save"
    "click button.cancel": "hideEditableElement"
    "mouseover .questionSetPropertyName": "showDescription"
    "mouseleave .questionSetPropertyName": "hideDescription"
    "click .toggleNext": "toggleNext"
    "click .hljs-string": "clickParent"

  # Hack because json elements get a class that doesn't bubble events
  clickParent: (event) =>
    $(event.target).parent().click()

  toggleNext: (event) =>
    $(event.target).next().toggle()

  showDescription: (event) =>
    $(event.target).find(".description").show()

  hideDescription: (event) =>
    $(event.target).find(".description").hide()

  edit: (event) =>
    console.log $(event.target)
    $(event.target).parent().next().show()[0].scrollIntoView
      behavior: "smooth"

  hideEditableElement: (event) =>
    element = $(event.target).parent().hide()

  save: (event) =>
    @hideEditableElement(event)
    clickedElement = $(event.target)
    clickedElement.parent().hide()
    updatedTextareaElement = clickedElement.prev()
    property = updatedTextareaElement.attr("data-propertyName")
    switch property
      when "fullDocument"
        @questionSet.data = JSON.parse(updatedTextareaElement.val())
      when "questionData"
        questionIndex = updatedTextareaElement.attr("data-question-index")
        @questionSet.data.questions[questionIndex] = JSON.parse(updatedTextareaElement.val())
      else # Question set properties
        @questionSet.data[property] = updatedTextareaElement.val()
    @questionSet.save().then =>
      @render()

  login: =>
    @target.username = @$("#username").val()
    @target.password = @$("#password").val()
    Cookie.set("username", @target.username)
    Cookie.set("password", @target.password)
    @fetchAndRender()

  fetchAndRender: =>
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

  render: =>
    fullQuestionSetAsPrettyPrintedJSON = JSON.stringify(@questionSet.data, null, 2)
    @$el.html "
      <style>
        .description{
          display:none
        }
        .questionSetProperty{
          margin-top:5px;
        }
        textarea{
          width:600px;
          height:200px;
        }
      </style>
      <h1>Question Set: #{titleize(@questionSet.name())}</h1>
      <div id='questionSet'>
        <h3>
          Click on any dark area to edit.
        </h3>
        <h2>Question Set Level Configuration</h2>
        #{
          _(@questionSet.data).map (value, property) =>
            propertyMetadata = QuestionSet.properties()[property]
            if propertyMetadata
              switch propertyMetadata["data-type"]
                when "coffeescript"
                  "
                    <div>
                      <div class='questionSetProperty'>
                        <div class='questionSetPropertyName'>
                          #{property}
                          <div class='description'>
                            #{propertyMetadata.description}
                          </div>
                        </div>
                        <pre>
                          <code class='toggleToEdit questionSetPropertyValue #{propertyMetadata["data-type"]}'>
                            #{value}
                          </code>
                        </pre>
                        <div style='display:none'>
                          <textarea class='questionSetPropertyValue' data-propertyName='#{property}' id='textarea-#{slugify(property)}'>#{value}</textarea>
                          <button class='save'>Save</button>
                          <button class='cancel'>Cancel</button>
                        </div>
                      </div>
                    </div>
                  "
                when "object"
                  "
                    <textarea>#{JSON.stringify value}</textarea>
                  "
                else
                  console.error "Unknown type: #{propertyMetadata["data-type"]}: #{value}"
                  alert "Unhandled type"
            else
              console.error "Unknown property: #{property}: #{value}"
          .join("")
        }

          #{
            allProperties = Object.keys(QuestionSet.properties())
            configuredProperties = Object.keys(@questionSet.data)
            availableProperties = _(allProperties).difference(configuredProperties)
            if availableProperties.length isnt 0
              "
              <h3>Additional Configuration Options</h3>
              <select>
                #{
                _(availableProperties).map (property) =>
                  "<option>#{property}</option>"
                .join("")
                }
              </select>
              "
            else
              ""
          }

        <h2>Questions</h2>

        #{
          _(@questionSet.data.questions).map (question, index) =>
            "
            <div class='toggleNext question-label'>
              #{question.label}
            </div>
            <pre style='display:none'>
              <code class='toggleToEdit'>
                #{JSON.stringify(question, null, 2)}
              </code>
            </pre>
            <div style='display:none'>
              <textarea data-propertyName='questionData' data-question-index='#{index}'>
                #{JSON.stringify(question, null, 2)}
              </textarea>
              <button class='save'>Save</button>
              <button class='cancel'>Cancel</button>
            </div>
            "
          .join("")
          
        }

        <h2>Full Question Set Definition</h2>
        <pre>
          <code class='toggleToEdit'>
            #{fullQuestionSetAsPrettyPrintedJSON}
          </code>
        </pre>
        <div style='display:none'>
          <textarea data-propertyName='fullDocument' style='height:600px;'>
            #{fullQuestionSetAsPrettyPrintedJSON}
          </textarea>
          <button class='save'>Save</button>
          <button class='cancel'>Cancel</button>
        </div>
      </div>

    "
    hljs.configure
      languages: ["coffeescript", "json"]
      useBR: false

    @$('pre code').each (i, snippet) =>
      hljs.highlightBlock(snippet);


  loginForm: => "
    Username/Password required for database:
    <div>
      Username: <input id='username'/>
    </div>
    <div>
      <input type='password' id='password'/>
    </div>
    <button id='login'>Login</button>
  "

module.exports = QuestionSetView
