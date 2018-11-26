$ = require 'jquery'
Backbone = require 'backbone'
Backbone.$  = $
_ = require 'underscore'
global.Cookie = require 'js-cookie'
dasherize = require("underscore.string/dasherize")
titleize = require("underscore.string/titleize")
humanize = require("underscore.string/humanize")
slugify = require("underscore.string/slugify")
get = require 'lodash/get'
set = require 'lodash/set'
isJSON = require('is-json');

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
    "click .toggleNext": "toggleNext"
    "click .hljs-string": "clickParent"

  # Hack because json elements get a class that doesn't bubble events
  clickParent: (event) =>
    $(event.target).parent().click()

  toggleNext: (event) =>
    $(event.target).next().toggle()

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
    updatedElement = clickedElement.prev()
    propertyPath = updatedElement.attr("data-property-path")
    updatedValue = updatedElement.val()
    updatedValue = JSON.parse(updatedValue) if isJSON(updatedValue)
    set(@questionSet, "data.#{propertyPath}", updatedValue)
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

  renderSyntaxHighlightedCodeWithTextareaForEditing: (propertyPath, preStyle = "") => 
    code = if propertyPath
      get(@questionSet.data, propertyPath)
    else
      @questionSet.data
    code = JSON.stringify(code, null, 2) if _(code).isObject()
    "
      <pre style='#{preStyle}'>
        <code class='toggleToEdit'>
          #{code}
        </code>
      </pre>
      <div style='display:none'>
        <textarea data-property-path=#{propertyPath}>
          #{code}
        </textarea>
        <button class='save'>Save</button>
        <button class='cancel'>Cancel</button>
      </div>
    "

  render: =>
    fullQuestionSetAsPrettyPrintedJSON = JSON.stringify(@questionSet.data, null, 2)
    @$el.html "
      <style>
        .description{
          font-size: small;
          color:gray
        }
        .questionSetProperty{
          margin-top:5px;
        }
        textarea{
          width:600px;
          height:200px;
        }
        code, .toggleToEdit:hover, .toggleNext:hover, .clickToEdit:hover{
          cursor: pointer
        }
        .question-label{
          font-weight: bold;
          font-size: large;

        }
        .clickToEdit{
          background-color: black;
          color: gray;
          padding: 2px;
        }
      </style>
      <h1>Question Set: #{titleize(@questionSet.name())}</h1>
      <div id='questionSet'>
        <h3>
          Click on any <span style='background-color:black; color:gray; padding:2px;'>dark area</span> to edit.
        </h3>
        <h2>Question Set Level Configuration</h2>
        #{
          _(@questionSet.data).map (value, property) =>
            propertyMetadata = QuestionSet.properties()[property]
            if propertyMetadata
              switch propertyMetadata["data-type"]
                when "coffeescript", "object"
                  "
                    <div>
                      <div class='questionSetProperty'>
                        <div class='questionSetPropertyName'>
                          #{property}
                          <div class='description'>
                            #{propertyMetadata.description}
                          </div>
                        </div>
                        #{
                          @renderSyntaxHighlightedCodeWithTextareaForEditing(property)
                        }
                      </div>
                    </div>
                  "
                else
                  console.error "Unknown type: #{propertyMetadata["data-type"]}: #{value}"
                  alert "Unhandled type"
            else
              return if _(["_id", "_rev", "isApplicationDoc", "collection", "couchapp", "questions"]).contains property
              console.error "Unknown question set property: #{property}: #{value}"
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
            <div style='display:none; margin-left: 10px; padding: 5px; background-color:#DCDCDC'>
              <div>Properties Configured:</div>
              #{
                _(question).map (value, property) =>
                  propertyMetadata = QuestionSet.questionProperties()[property]
                  if propertyMetadata 
                    propertyPath = "questions[#{index}][#{property}]"
                    "
                    <hr/>
                    <div class='questionPropertyName'>
                      #{property}
                      <div class='description'>
                        #{propertyMetadata.description}
                      </div>
                    </div>
                    " +  switch propertyMetadata["data-type"]
                      when "coffeescript", "text", "json"
                        "
                          <div>
                            <div class='questionProperty'>
                              #{
                                @renderSyntaxHighlightedCodeWithTextareaForEditing(propertyPath)
                              }
                            </div>
                          </div>
                        "
                      when "select"
                        "
                          <div>
                            #{property}: <span style='font-weight:bold'>#{question[property]}</span> 
                            <span style='margin-left: 10xp; font-size:small;' class='toggleNext clickToEdit'>
                              update
                            </span>

                            <div style='display:none'>
                              <select data-property-path='#{propertyPath}'>
                              #{
                                _(propertyMetadata.options).map (optionMetadata, option) =>
                                  "<option #{if option is question[property] then "selected=true" else ""}>#{option}</option>"
                                .join ""
                              }
                              </select>
                              <button class='save'>Save</button>
                              <button class='cancel'>Cancel</button>
                            </div>
                          </div>
                        "
                      when "array"
                        "
                          <div>
                            Items: 
                            <ul>
                              #{
                                _(value.split(/, */)).map (item) =>
                                  "<li>#{item}</li>"
                                .join("")
                              }
                            </ul>
                            <span style='margin-left: 10xp; font-size:small;' class='toggleNext clickToEdit'>
                              update
                            </span>
                            <div style='display:none'>
                              <textarea data-property-path=#{propertyPath}>
                                #{value}
                              </textarea>
                              <button class='save'>Save</button>
                              <button class='cancel'>Cancel</button>
                            </div>
                          </div>
                        "

                      else
                        console.error "Unknown type: #{propertyMetadata["data-type"]}: #{value}"
                  else
                    console.error "Unknown property: #{property}: #{value}"
                .join("")
                #
                #

              }
              #{
                allProperties = Object.keys(QuestionSet.questionProperties())
                configuredProperties = Object.keys(question)
                availableProperties = _(allProperties).difference(configuredProperties)
                if availableProperties.length isnt 0
                  "
                  <h3>Additional Available Configuration Options</h3>
                  <ul>
                    #{
                    _(availableProperties).map (property) =>
                      "<li>
                        #{property} - <span class='addProperty clickToEdit' property='property' data-property-path='questions[#{index}]'>add</span> - #{QuestionSet.questionProperties()[property].description}
                      </li>"
                    .join("")
                    }
                  </ul>
                  "
                else
                  ""
              }


              <div class='toggleNext clickToEdit'>
                Edit Question Directly
              </div>
              #{
                @renderSyntaxHighlightedCodeWithTextareaForEditing("questions[#{index}]", "display:none")
              }
            </div>
            "
          .join("")
          
        }

        <h2 class='toggleNext'>Full Question Set Definition</h2>
        #{
          @renderSyntaxHighlightedCodeWithTextareaForEditing(null, "display:none")
        }
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
