crypto = require('crypto')
Tabulator = require 'tabulator-tables'

class UsersView extends Backbone.View
  el:'#content'

  events:
    "click button#addUser": "addUser"
    "click button#addUsers": "addUsers"
    "click button#resetPassword": "resetPassword"
    "click button#addColumn": "addColumn"
    "click button#addTamarindColumns": "addTamarindColumns"

  addTamarindColumns: =>
    @newColumns or= []
    @newColumns.push "Tamarind Access"
    @newColumns.push "Tamarind CSV"
    @newColumns.push "Tamarind Indexes Queries Calculated-Fields"
    @newColumns.push "Tamarind Editing"
    @render()

  addColumn: =>
    @newColumns or= []
    @newColumns.push prompt "What is the new column?"
    @render()

  addUser: =>
    username = prompt "What is the new username (phone number for DMSOs)?"
    username = "user.#{username.toLowerCase()}"
    password = prompt "What is the new password?"
    password = (crypto.pbkdf2Sync password, '', 1000, 256/8, 'sha256').toString('base64')
    userDoc =
      _id: username
      district: []
      name: ""
      email: ""
      roles: []
      comments: ""
      inactive: false
      collection: "user"
      isApplicationDoc: true
      password: password

    @tabulator.addRow userDoc
      
    Jackfruit.database.upsert data._id,  =>
      userDoc

  resetPassword: (username) =>
    unless _(username).isString()
      username = prompt "What is the user's id or username that you wish to reset?"
      username = "user.#{username}" unless username.match(/^user/)

    unless (_(await @getUsers()).pluck("_id")).includes username
      alert "Invalid username: #{username}"
      @resetPassword(null)

    newPass = prompt "Enter the new password"
    if newPass is "" or newPass is null
      alert "Password can't be blank"
      @resetPassword(username)
    else
      await Jackfruit.database.upsert username, (doc) =>
        doc.password = (crypto.pbkdf2Sync newPass, '', 1000, 256/8, 'sha256').toString('base64')
        doc
      .catch (error) =>
        alert ("Error: #{JSON.stringify error}")
        console.error error
      alert "Password has been reset"

  getUsers: =>
    Jackfruit.database.allDocs
      startkey: "user"
      endkey: "user\ufff0"
      include_docs: true
    .catch (error) -> console.error error
    .then (result) =>
      console.log result
      Promise.resolve _(result.rows).pluck("doc")

  render: =>
    @$el.html "
      <h2>Users</h2>
      Click on a cell to edit the user. Districts and roles allow for multiple options to be selected, just press the tab button after the selection have been made.<br/>
      <button id='addUser'>Add a new user</button>
      <button id='addUsers'>Add multiple users from JSON</button>
      <button id='resetPassword'>Reset a user's password</button>
      <button id='addColumn'>Add a column</button>
      <button id='addTamarindColumns'>Add Tamarind columns</button>

      <div id='userTabulator'></div>
    "

    @users = await @getUsers()

    userProperties = {}
    for user in @users
      for key in Object.keys(user)
        userProperties[key] = true

    userProperties = _(Object.keys(userProperties)).difference [
      "_rev"
      "token"
      "couchapp"
      "password"
      "isApplicationDoc"
      "collection"
    ]

    userProperties = userProperties.concat(@newColumns) if @newColumns

    columns = for field in userProperties

      result = {
        title: field
        field: field
        headerFilter: "input"
      }

      result.editor = switch field
        when "_id" then null
        when "inactive" then "tickCross"
        when "roles"
          result.editorParams = 
            values: ["reports","admin","researcher","DMSO"]
            multiselect: true
          "select"
        else "input"

      result

    @tabulator = new Tabulator "#userTabulator",
      height: 400
      columns: columns
      data: await @getUsers()
      cellEdited: (cell) =>
        oldValue = cell.getOldValue()
        value = cell.getValue()
        isUpdated = if _(value).isArray()
          not _(oldValue).isEqual(value)
        else
          cell.getOldValue() isnt cell.getValue() and
          #cell.getOldValue() isnt null and 
          cell.getValue() isnt ""

        console.log isUpdated

        if isUpdated and confirm("Are you sure you want to change #{cell.getField()} for #{cell.getData()._id} from '#{oldValue}' to '#{value}'")
          data = cell.getRow().getData()
          delete data._rev
          Jackfruit.database.upsert data._id,  =>
            data
        else
          cell.restoreOldValue()

    @$("#addTamarindColumns").hide() if @tabulator.getColumns().map((n) => n.getField()).includes "Tamarind Access"


  addUsers: (users) =>

    unless _(users).isArray()
      users = JSON.parse(prompt """Please paste in a JSON file of the user data. You can use a CSV2JSON online converter to convert from a spreadsheet. It at least needs a name field, but any others will be included as well. For example:
        [
          {
            "name": "SHUWEKHA RAJAB MASSOUD",
            "mobile": "0235651058",
            "facility": "CHAKE CHAKE HOSPITAL",
            "district": "CHAKE CHAKE"
          },
          {
            "name": "RAMADHAN ABDALLAH MOHAMMED",
            "mobile": "0656443230",
            "facility": "MWANAMASHUNGI DISP",
            "district": "CHAKE CHAKE"
          }
        ]
      """)

    usernamesAndPasswords = ""
    userDocs = for user in users

      userDoc = {}
      for property,value of user
        userDoc[property] = value

      # Make sure these at least have a blank value
      for property in ["name","email","comments"]
        userDoc[property] or= ""

      if user.name and not user.username
        user.username = user.name.split(/ /).map (name) =>
          name.replace(/[^a-zA-Z]/)[0..1]
        .join("")

      username = user.username.toLowerCase() or throw "Missing username"
      passwordUnencrypted = username[0..3] + Math.random().toString()[2..3]
      username = user.password or "user.#{username}"
      password = (crypto.pbkdf2Sync passwordUnencrypted, '', 1000, 256/8, 'sha256').toString('base64')
      usernamesAndPasswords += "#{username}: #{passwordUnencrypted}\n"

      userDoc["_id"] = username
      userDoc["roles"] = []
      userDoc["inactive"] = false
      userDoc["collection"] = "user"
      userDoc["isApplicationDoc"] = true
      userDoc["password"] = password

      userDoc

    if confirm "Are you sure you want to create #{userDocs.length} users: #{_(userDocs).pluck("_id").join(", ")}?"
      console.log userDocs
      console.log "Here are the usernames and passwords, the passwords can not be shown again:\n#{usernamesAndPasswords}"

    Jackfruit.database.bulkDocs userDocs
    .catch (error) => alert error

      #@tabulator.addRow userDoc
        
      #await Jackfruit.database.upsert userDoc._id,  =>
      #  userDoc
      #.catch (error) => alert error

    await @render()
    @$el.append "<span style='background-color:yellow'>Here are the new usernames and passwords, the passwords can not be shown again:<br/>
      #{usernamesAndPasswords}</span>"

module.exports = UsersView
