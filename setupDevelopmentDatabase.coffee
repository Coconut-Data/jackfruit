PouchDB = require 'pouchdb'
_ = require 'underscore'
AppConfig = require '../config.json'

config = {
  zanzibar:
    source: "https://#{AppConfig.targetUrl}/zanzibar"
    target: "https://#{AppConfig.targetUrl}/zanzibar-development"
    viewsForDocs: [
      "questions"
      "docIDsForUpdating"
    ]
    docs: [
      "client encryption key"
      "_design/docIDsForUpdating"
    ]
    docRanges: [
      [
        "user"
        "user\uf000"
      ]
    ]
}

[application, username, password] = process.argv[2..4]

unless password?
  console.error "Usage: coffee setupDevelopmentDatabase.coffee [application] [username] [password]"
  process.exit(1)

main = =>

  source = new PouchDB "#{config[application].source}",
    auth:
      username: username
      password: password
  target = new PouchDB "#{config[application].target}",
    auth:
      username: username
      password: password

  doc_ids = for view in config[application].viewsForDocs
    await source.query view
    .catch (error) => console.error error
    .then (result) =>
      Promise.resolve(_(result.rows).pluck "id")

  doc_ids = doc_ids.concat(for range in config[application].docRanges
    await source.allDocs
      startkey: range[0]
      endkey: range[1]
    .catch (error) => console.error error
    .then (result) =>
      Promise.resolve(_(result.rows).pluck "id")
  )

  doc_ids = doc_ids.concat(config[application].docs)
  doc_ids = _(doc_ids).chain().flatten().compact().uniq().value()

  console.log doc_ids

  source.replicate.to target,
    doc_ids: doc_ids
  .on "progress", (progress) => console.log progress
  .on "complete", (complete) => 
    console.log compete
    console.log "Done"

main()
