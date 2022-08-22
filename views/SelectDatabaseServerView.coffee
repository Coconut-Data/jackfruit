Backbone = require 'backbone'
AppConfig = require '../config.json'

class SelectDatabaseServerView extends Backbone.View

  knownDatabaseServers:
    Zanzibar: "https://#{AppConfig.targetUrl}"
    Local: "http://localhost:5984"

  render: =>
    "
      <h1>Select a Database Server</h1>
      <table>
        <thead>
        </thead>
        <tbody>
        #{
          for name, url in knownDatabaseServers
            "
            <tr>
              <td><a href='#database/#{name}'>#{name}</a></td>
              <td><a href='#database/#{name}'>#{url}</a></td>
            </tr>
            "
        }
        </tbody>
      </table>
    "

module.exports = SelectDatabaseServerView
