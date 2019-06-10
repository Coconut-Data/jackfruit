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
unset = require 'lodash/unset'
pullAt = require 'lodash/pullAt'
isJSON = require('is-json');
striptags = require 'striptags'
Sortable = require 'sortablejs'
global.Coffeescript = require 'coffeescript'

hljs = require 'highlight.js/lib/highlight';
coffeescriptHighlight = require 'highlight.js/lib/languages/coffeescript';
hljs.registerLanguage('coffeescript', coffeescriptHighlight);

global.QuestionSet = require '../models/QuestionSet'

class QuestionSetView extends Backbone.View
  events: =>
    "click .toggleToEdit": "edit"
    "click button.save": "save"
    "click button.cancel": "hideEditableElement"
    "click .toggleNext": "toggleNext"
    "click .hljs-string": "clickParent"
    "click .addProperty": "addProperty"
    "click .remove": "removeProperty"
    "click #showQuestionTypes": "showQuestionTypes"
    "click .addNewQuestion": "addNewQuestion"
    "click .removeQuestion": "removeQuestion"
    "click .updateTestCode": "updateTestCode"
    "click .runTestCode": "runTestCode"

  removeQuestion: =>
    removeQuestionElement = @$(event.target)
    questionIndex = removeQuestionElement.attr("data-question-index")
    questionLabel = removeQuestionElement.attr("data-question-label")
    if confirm "Are you sure you want to remove: #{questionLabel}?"
      pullAt(@questionSet.data.questions, [questionIndex]) # Removes element at index questionIndex
      @changesWatcher.cancel()
      await @questionSet.save()
      @activeQuestionLabel = null
      @render()

  showQuestionTypes: =>
    @$("#availableQuestionTypes").show()

  addNewQuestion: (event) =>
    addNewQuestionTypeElement = @$(event.target)
    type = addNewQuestionTypeElement.attr("data-question-type")
    label = @$("#newQuestionLabel").val()
    if label is ""
      alert("Label for new question can't be empty")
      return

    newQuestion =
      label: label
      type: type

    if type is "radio"
      newQuestion["radio-options"] = "Yes,No"

    @questionSet.data.questions.push newQuestion

    @changesWatcher.cancel()
    await @questionSet.save()
    @activeQuestionLabel = label
    @render()

  removeProperty: (event) =>
    removePropertyElement = @$(event.target)
    propertyPath = removePropertyElement.attr("data-property-path")
    if confirm "Are you sure you want to remove: #{propertyPath}?"
      unset(@questionSet, "data.#{propertyPath}")
      @changesWatcher.cancel()
      await @questionSet.save()
      @activeQuestionLabel = removePropertyElement.closest(".questionDiv").attr("data-question-label")
      @render()

  addProperty: (event) =>
    addPropertyElement = @$(event.target)
    propertyPath = addPropertyElement.attr("data-property-path")
    propertyType = if propertyPath.startsWith("questions[")
      # just want the property part of "questions[1][action_on_change]"
      property = propertyPath.replace(/^.*\[/,"").replace(/\]/,"")
      QuestionSet.questionProperties[property]["data-type"]
    else
      QuestionSet.properties[propertyPath]["data-type"]
      
    initialValue = switch propertyType
      when "coffeescript" then "# executable coffeescript code goes here"
      when "object" then "{example:\"data\"}"
      else null

    set(@questionSet, "data.#{propertyPath}", initialValue)
    @changesWatcher.cancel()
    await @questionSet.save()
    @activeQuestionLabel = addPropertyElement.closest(".questionDiv").attr("data-question-label")
    @render()
    newElement = $(".questionPropertyName:visible:contains(#{property})")
    newElement[0].scrollIntoView()
    newElement.addClass("highlight")
    newElement.next().addClass("highlight")
    _.delay =>
      newElement.removeClass("highlight")
      newElement.next().removeClass("highlight")
    , 5000

  # Hack because json elements get a class that doesn't bubble events
  clickParent: (event) =>
    $(event.target).parent().click()

  toggleNext: (event) =>
    elementToToggle = $(event.target).next()
    if elementToToggle.hasClass("questionDiv")
      @activeQuestionLabel = elementToToggle.attr("data-question-label")
    elementToToggle.toggle()

  edit: (event) =>
    $(event.target).closest("pre").next().show()[0].scrollIntoView
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
    @changesWatcher.cancel()
    @questionSet.save().then =>
      @render()


  renderSyntaxHighlightedCodeWithTextareaForEditing: (propertyPath, preStyle = "") => 
    code = if propertyPath
      get(@questionSet.data, propertyPath)
    else
      @questionSet.data
    code = JSON.stringify(code, null, 2) if _(code).isObject()

    # https://stackoverflow.com/questions/19913667/javascript-regex-global-match-groups
    regex = /ResultOfQuestion\("(.+?)"\)/g
    matches = []
    questionsReferredTo = []
    while (matches = regex.exec(code))
      questionsReferredTo.push("#{matches[1]}: Test Value")

    questionsReferredTo = _(questionsReferredTo).unique()

    "
      <pre style='#{preStyle}'><code class='toggleToEdit'>#{code}</code></pre>
      <div class='codeEditor' style='display:none'>
        <textarea style='display:block' class='code' data-property-path=#{propertyPath}>#{code}</textarea>
        <button class='save'>Save</button>
        <button class='cancel'>Cancel</button>
        <br/>
        <br/>
        <span style='background-color: black; color: gray; padding: 2px; border: solid 2px;' class='toggleNext'>Test It</span>
        <div style='display:none'>
          Set ResultOfQuestion values (e.g. Name: Mike McKay, Birthdate: 2012-11-27 or put each pair on a new line)
          <br/>
          <textarea style='height:60px' class='testResultOfQuestion'>#{questionsReferredTo.join("""\n""")}</textarea>
          <br/>
          <br/>
          Set the value to use for testing the current value
          <br/>
          <input class='testValue'></input>
          <br/>
          <br/>
          Test Code: 
          <br/>
          <textarea class='testCode'></textarea>
          <br/>
          <button class='updateTestCode'>Update Test Code</button>
          <button class='runTestCode'>Run</button>
        </div>
      </div>
    "

  updateTestCode: (event) =>
    codeEditor = $(event.target).closest(".codeEditor")
    originalCode = codeEditor.find(".code").val()
    testResultOfQuestion = codeEditor.find(".testResultOfQuestion").val()
    testValue = codeEditor.find(".testValue").val()
    testCodeElement = codeEditor.find(".testCode")
    typeOfCode = codeEditor.closest(".code").attr("data-type-of-code")

    testCodeElement.val """
      #{
        if testValue isnt ""
          "value = '#{testValue}'"
        else
          ""
      }#{
        if testResultOfQuestion isnt ""
          """
            ResultOfQuestion = (val) =>
              switch val
                #{
                  (for questionValue in testResultOfQuestion.split(/ *(,|\n) */)
                    [question,value] = questionValue.split(/: */)
                    "when '#{question}' then '#{value}'"
                  ).join("\n    ")
                }

          """
        else ""
      }
      result = #{originalCode}

      #{
        switch typeOfCode
          when "validation"
            """alert(if result? then "\#{result}: Not Valid" else "Valid")"""
          when "skip_logic"
            """alert(if result then "\#{result}: Skipped" else "\#{result}: Not Skipped")"""
          else
            """alert(result)"""
      }

    """

  runTestCode: (event) =>
    testCodeValue = $(event.target).siblings(".testCode").val()
    try
      Coffeescript.eval testCodeValue
    catch error
      alert "Error: #{error}"

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
          border: solid 2px;
        }
        .highlight{
          background-color: yellow
        }

      </style>
      <h2>Application: <a href='#application/#{Jackfruit.application}'>#{Jackfruit.application}</a></h2>
      <h2>Question Set: #{titleize(@questionSet.name())}</h2>
      <div id='questionSet'>
        <!--
        <div class='description'>
          Click on any <span style='background-color:black; color:gray; padding:2px;'>dark area</span> below to edit.
        </div>
        -->
        <h3 style='display:inline'>Configuration</h3>
        <span class='toggleNext clickToEdit'>Edit</span>
        <div style='display:none'>
          <div class='description'>These options configure the entire question set as opposed to individual questions. For example, this is where you can run code when the page loads or when the question set is marked complete.</div>
          #{
            console.log @questionSet.data
            _(@questionSet.data).map (value, property) =>
              propertyMetadata = QuestionSet.properties[property]
              if propertyMetadata
                switch propertyMetadata["data-type"]
                  when "coffeescript", "object"
                    "
                      <div>
                        <div class='questionSetProperty'>
                          <div class='questionSetPropertyName'>
                            #{property} <span style='#{if property is "label" then "display:none" else ""}' class='remove clickToEdit' data-property-path='#{property}'>remove</span>
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
            allProperties = Object.keys(QuestionSet.properties)
            configuredProperties = Object.keys(@questionSet.data)
            availableProperties = _(allProperties).difference(configuredProperties)
            if availableProperties.length isnt 0
              "
              <h3>Unused Question Set Configuration Options</h3>
              #{
                (for property in availableProperties
                  "<li>
                    #{property} 
                    <span 
                      class='addProperty clickToEdit' 
                      data-property-path='#{property}'
                    >add</span> 
                    <span class='description'>#{QuestionSet.properties[property].description}</span>
                  </li>"
                ).join("")
              }
              "
            else
              ""
          }
        </div>

        <h2>Questions</h2>
        <div class='description'>Below is a list of all of the questions in this question set. You can click on a question below to change it, or drag the arrows up and down to reorder.</div>

        <div id='questions'>

        #{
          _(@questionSet.data.questions).map (question, index) =>
            "
            <div class='sortable' id='question-div-#{index}'>
              <div class='toggleNext question-label'>
                <span class='handle'>&#x2195;</span> 
                #{striptags(question.label)}
                <div style='margin-left: 20px; font-weight:normal;font-size:small'>
                  #{if question["radio-options"] then "<div>#{question["radio-options"]}</div>" else ""}
                  #{if question["skip_logic"] then "<div>Skip if: <span style='font-family:monospace'>#{question["skip_logic"]}</span></div>" else ""}
                </div>

              </div>
              <div class='questionDiv' data-question-label='#{question.label}' style='display:none; margin-left: 10px; padding: 5px; background-color:#DCDCDC'>
                <div>Properties Configured:</div>
                #{
                  _(question).map (value, property) =>
                    propertyMetadata = QuestionSet.questionProperties[property]
                    if propertyMetadata 
                      propertyPath = "questions[#{index}][#{property}]"
                      "
                      <hr/>
                      <div class='questionPropertyName'>
                        #{property} <span style='#{if property is "label" or property is "type" then "display:none" else ""}' class='remove clickToEdit' data-property-path='#{propertyPath}'>remove</span>
                        
                        <div class='description'>
                          #{propertyMetadata.description}
                        </div>
                      </div>
                      " +  switch propertyMetadata["data-type"]
                        when "coffeescript", "text", "json"
                          "
                            <div>
                              <div data-type-of-code='#{property}' class='questionProperty code'>
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
                                <select style='display:block' data-property-path='#{propertyPath}'>
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
                          value = "Example Option 1, Example Option 2" unless value
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
                                <textarea style='display:block' data-property-path=#{propertyPath}>#{value}</textarea>
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
                  allProperties = Object.keys(QuestionSet.questionProperties)
                  configuredProperties = Object.keys(question)
                  availableProperties = _(allProperties).difference(configuredProperties)
                  if availableProperties.length isnt 0
                    "
                    <h3>Unused Question Configuration Options</h3>
                    <ul>
                      #{
                      _(availableProperties).map (property) =>
                        "<li>
                          #{property} 
                          <span 
                            class='addProperty clickToEdit' 
                            data-property-path='questions[#{index}][#{property}]'
                            data-question-index='#{index}'
                          >
                            add
                          </span> 
                          <span class='description'>#{QuestionSet.questionProperties[property].description}</span>
                        </li>"
                      .join("")
                      }
                    </ul>
                    "
                  else
                    ""
                }

                <span data-question-label='#{question.label}' data-question-index='#{index}' class='removeQuestion clickToEdit'>
                  Remove Question
                </span>
                <br/>
                <br/>
                <span class='toggleNext clickToEdit'>
                  Edit Question Directly
                </span>
                #{
                  @renderSyntaxHighlightedCodeWithTextareaForEditing("questions[#{index}]", "display:none")
                }
              </div>
            </div>
            "
          .join("")
          
        }
        </div>
        <div style='margin-top:20px'>
          <span class='clickToEdit' id='showQuestionTypes'>Add new question</span>
          <div id='availableQuestionTypes' style='display:none'>
            <div>
              <label for='newQuestionLabel'>Label for new question:</label>
              <input id='newQuestionLabel'/>
            </div>
            Choose the type of question to add:
            <ul>
            #{
              (for questionType, metadata of QuestionSet.questionProperties.type.options
                "
                <li>
                  <span>#{questionType}</span>
                  <span data-question-type='#{questionType}' class='clickToEdit addNewQuestion'>add</span>
                  <span class='description'>
                    #{metadata.description}
                  </span>
                </li>
                "
              ).join("")
            }
            </ul>
          </div>
        </div>

        <hr/>
        <div class='description'>To view and edit the raw JSON code defining this question set you can click the heading below.</div>
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

    @sortable = Sortable.create document.getElementById('questions'),
      handle: ".handle"
      onUpdate: (event) =>
        # Reorder the array
        # https://stackoverflow.com/a/2440723/266111
        @sortable.option("disabled", true)
        @questionSet.data.questions.splice(event.newIndex, 0, @questionSet.data.questions.splice(event.oldIndex, 1)[0])
        @changesWatcher.cancel()
        await @questionSet.save()
        @render()
        @sortable.option("disabled", false)

    @openActiveQuestion()
    Jackfruit.database.changes
      limit:1
      descending:true
    .then (change) =>  
      console.log change.last_seq
      @changesWatcher = Jackfruit.database.changes
        live: true
        doc_ids: [router.questionSetView.questionSet.data._id]
        since: change.last_seq
      .on "change", (change) =>
        console.log change
        @changesWatcher.cancel()
        if confirm("This question set has changed - someone else might be working on it. Would you like to refresh?")
          @questionSet.fetch().then => @render()







  openActiveQuestion: =>
    if @activeQuestionLabel
      questionElement = @$(".toggleNext.question-label:contains(#{@activeQuestionLabel})")
      questionElement.click()
      questionElement[0].scrollIntoView()

module.exports = QuestionSetView
