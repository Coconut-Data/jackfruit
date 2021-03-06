Backbone = require 'backbone'

class SelectServerView extends Backbone.View

  render: =>
    @$el.html "
      <h1>Select a Database Server</h1>
      <table>
        <thead>
        </thead>
        <tbody>
        #{
          (for name, url of Jackfruit.knownDatabaseServers
            "
            <tr style='height:50px;'>
              <td><a href='#server/#{name}'>#{name}</a></td>
              <td><a href='#server/#{name}'>#{if _(url).isObject() then "AWS" else url}</a></td>
            </tr>
            "
          ).join("")
        }
        </tbody>
      </table>
    "

module.exports = SelectServerView
