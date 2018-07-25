# Description:
#   Interact with your Jenkins CI server
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_JENKINS_URL
#   HUBOT_JENKINS_AUTH
#   HUBOT_JENKINS_{1-N}_URL
#   HUBOT_JENKINS_{1-N}_AUTH
#
#   Auth should be in the "user:access-token" format.
#
# Commands:
#   hubot jenkins aliases - lists all saved job name aliases
#   hubot jenkins b <jobNumber> - builds the job specified by jobNumber. List jobs to get number.
#   hubot jenkins b <jobNumber>, <params> - builds the job specified by jobNumber with parameters as key=value&key2=value2. List jobs to get number.
#   hubot jenkins build <job> - builds the specified Jenkins job
#   hubot jenkins build <job>, <params> - builds the specified Jenkins job with parameters as key=value&key2=value2
#   hubot jenkins d <jobNumber> - Describes the job specified by jobNumber. List jobs to get number.
#   hubot jenkins describe <job> - Describes the specified Jenkins job
#   hubot jenkins getAlias <name> - Retrieve value of job name alias
#   hubot jenkins list <filter> - lists Jenkins jobs grouped by server
#   hubot jenkins l <jobNumber> - Details about the last build for the job specified by jobNumber. List jobs to get number.
#   hubot jenkins last <job> - Details about the last build for the specified Jenkins job
#   hubot jenkins servers - Lists known jenkins servers
#   hubot jenkins setAlias <name>, <value> - creates job name alias
#   hubot jenkins remAlias <name> - removes job name alias
#
# Author:
#   wintondeshong
# Contributor:
#   zack-hable


Array::where = (query) ->
  return [] if typeof query isnt "object"
  hit = Object.keys(query).length
  @filter (item) ->
    match = 0
    for key, val of query
      match += 1 if item[key] is val
    if match is hit then true else false


class HubotMessenger
  constructor: (msg) ->
    @msg = msg

  msg: null

  _prefix: (message) =>
    "Jenkins says: #{message}"

  reply: (message, includePrefix = false) =>
    @msg.reply if includePrefix then @_prefix(message) else message

  send: (message, includePrefix = false) =>
    @msg.send if includePrefix then @_prefix(message) else message

  setMessage: (message) =>
    @msg = message


class JenkinsServer
  url: null
  auth: null
  _hasListed: false
  _jobs: null
  _querystring: null

  constructor: (url, auth) ->
    @url = url
    @auth = auth
    @_jobs = []
    @_querystring = require 'querystring'

  hasInitialized: ->
    @_hasListed

  addJob: (job) =>
    @_hasListed = true
    @_jobs.push job if not @hasJobByName job.name

  getJobs: =>
    @_jobs

  hasJobs: =>
    @_jobs.length > 0

  hasJobByName: (jobName) =>
    jobName = @_querystring.unescape(jobName).trim()
    @_jobs.where(name: jobName).length > 0


class JenkinsServerManager extends HubotMessenger
  _servers: []

  constructor: (msg) ->
    super msg
    @_loadConfiguration()

  getServerByJobName: (jobName) =>
    @send "ERROR: Make sure to run a 'list' to update the job cache" if not @serversHaveJobs()
    for server in @_servers
      return server if server.hasJobByName(jobName)
    null

  hasInitialized: =>
    for server in @_servers
      return false if not server.hasInitialized()
    true

  listServers: =>
    @_servers

  serversHaveJobs: =>
    for server in @_servers
      return true if server.hasJobs()
    false

  servers: =>
    for server in @_servers
      jobs = server.getJobs()
      message = "- #{server.url}"
      for job in jobs
        message += "\n-- #{job.name}"
      @send message

  _loadConfiguration: =>
    @_addServer process.env.HUBOT_JENKINS_URL, process.env.HUBOT_JENKINS_AUTH

    i = 1
    while true
      url = process.env["HUBOT_JENKINS_#{i}_URL"]
      auth = process.env["HUBOT_JENKINS_#{i}_AUTH"]
      if url and auth then @_addServer(url, auth) else return
      i += 1

  _addServer: (url, auth) =>
    @_servers.push new JenkinsServer(url, auth)


class HubotJenkinsPlugin extends HubotMessenger

  # Properties
  # ----------

  _serverManager: null
  _querystring: null
  # stores jobs, across all servers, in flat list to support 'buildById'
  _jobList: []
  _params: null
  # stores a function to be called after the initial 'list' has completed
  _delayedFunction: null


  # Init
  # ----

  constructor: (msg, serverManager) ->
    super msg
    @_querystring   = require 'querystring'
    @_serverManager = serverManager
    @setMessage msg

  _init: (delayedFunction) =>
    return true if @_serverManager.hasInitialized()
    @reply "This is the first command run after startup. Please wait while we perform initialization..."
    @_delayedFunction = delayedFunction
    @list true
    false

  _initComplete: =>
    if @_delayedFunction != null
      @send "Initialization Complete. Running your request..."
      setTimeout((() =>
        @_delayedFunction()
        @_delayedFunction = null
      ), 1000)


  # Public API
  # ----------

  buildById: =>
    return if not @_init(@buildById)
    job = @_getJobById()
    if not job
      @reply "I couldn't find that job. Try `jenkins list` to get a list."
      return

    @_setJob job
    @build()

  build: (buildWithEmptyParameters) =>
    return if not @_init(@build)
    job = @_getJob(true)
    server = @_serverManager.getServerByJobName(job)
    command = if buildWithEmptyParameters then "buildWithParameters" else "build"
    path = if @_params then "job/#{job}/buildWithParameters?#{@_params}" else "job/#{job}/#{command}"
    if !server
      @msg.send "I couldn't find any servers with a job called #{@_getJob()}.  Try `jenkins servers` to get a list."
      return
    @_requestFactorySingle server, path, @_handleBuild, "post"

  describeById: =>
    return if not @_init(@describeById)
    job = @_getJobById()
    if not job
      @reply "I couldn't find that job. Try `jenkins list` to get a list."
      return  
    @_setJob job
    @describe()

  describe: =>
    return if not @_init(@describe)
    job = @_getJob(true)
    server = @_serverManager.getServerByJobName(job)
    if !server
      @msg.send "I couldn't find any servers with a job called #{@_getJob()}.  Try `jenkins servers` to get a list."
      return
    @_requestFactorySingle server, "job/#{job}/api/json", @_handleDescribe

  getAlias: =>
    aliases    = @_getSavedAliases()
    aliasKey   = @msg.match[1]
    aliasValue = aliases[aliasKey]
    @msg.send "'#{aliasKey}' is an alias for '#{aliasValue}'"

  lastById: =>
    return if not @_init(@lastById)
    job = @_getJobById()
    if not job
      @reply "I couldn't find that job. Try `jenkins list` to get a list."
      return  
    @_setJob job
    @last()
	
  last: =>
    return if not @_init(@last)
    job = @_getJob()
    server = @_serverManager.getServerByJobName(job)
    path = "job/#{job}/lastBuild/api/json"
    if !server
      @msg.send "I couldn't find any servers with a job called #{@_getJob()}.  Try `jenkins servers` to get a list."
      return
    @_requestFactorySingle server, path, @_handleLast

  list: (isInit = false) =>
    @_requestFactory "api/json", if isInit then @_handleListInit else @_handleList

  listAliases: =>
    aliases  = @_getSavedAliases()
    response = []
    for alias, value of aliases
      response.push "-- Alias '#{alias}' for job '#{value}'"

    @msg.send "Aliases:\n#{response.join("\n")}"

  servers: =>
    return if not @_init(@servers)
    @_serverManager.servers()

  setAlias: =>
    aliases    = @_getSavedAliases()
    aliasKey   = @msg.match[1]
    aliasValue = @msg.match[2]
    if aliases[aliasKey]
      @msg.send "An alias already exists for #{aliasKey} and is mapped to #{aliasValue}.  Please use `jenkins remAlias #{aliasKey}` to remove this alias if you want to update the value."
      return
    aliases[aliasKey] = aliasValue
    @robot.brain.set 'jenkins_aliases', aliases
    @msg.send "'#{aliasKey}' is now an alias for '#{aliasValue}'"
	
  remAlias: =>
    aliases    = @_getSavedAliases()
    aliasKey   = @msg.match[1]
    delete aliases[aliasKey]
    @robot.brain.set 'jenkins_aliases', aliases
    @msg.send "'#{aliasKey}' has been removed"

  setMessage: (message) =>
    super message
    @_params = @msg.match[3]
    @_serverManager.setMessage message

  setRobot: (robot) =>
    @robot = robot

  # Utility Methods
  # ---------------

  _addJobsToJobsList: (jobs, server, outputStatus = false) =>
    response = ""
    filter = new RegExp(@msg.match[2], 'i')

    for job in jobs
      # Add the job to the @_jobList
      server.addJob(job)
      index = @_jobList.indexOf(job.name)
      if index == -1
        @_jobList.push job.name
        index = @_jobList.indexOf(job.name)

      state = if job.color == "red" then "FAIL" else "PASS"
      if filter.test job.name
        response += "[#{index + 1}] #{state} #{job.name} on #{server.url}\n"

    @send response if outputStatus

  _configureRequest: (request, server = null) =>
    defaultAuth = process.env.HUBOT_JENKINS_AUTH
    return if not server and not defaultAuth
    selectedAuth = if server then server.auth else defaultAuth
    #auth = new Buffer(selectedAuth).toString('base64')
    #request.headers Authorization: "Basic #{auth}"
    request.header('Content-Length', 0)
    request

  _describeJob: (job) =>
    response = ""
    response += "JOB: #{job.displayName}\n"
    response += "URL: #{job.url}\n"
    response += "DESCRIPTION: #{job.description}\n" if job.description
    response += "ENABLED: #{job.buildable}\n"
    response += "STATUS: #{job.color}\n"
    response += @_describeJobHealthReport(job.healthReport)
    response += if job._class.includes 'Project' then @_describeJobActions(job.actions) else @_describeJobActions(job.property)
    response

  _describeJobActions: (actions) =>
    parameters = ""
    for item in actions
      if item.parameterDefinitions
        for param in item.parameterDefinitions
          tmpDescription = if param.description then " - #{param.description} " else ""
          tmpDefault = if param.defaultParameterValue then " (default=#{param.defaultParameterValue.value})" else ""
          parameters += "\n  #{param.name}#{tmpDescription}#{tmpDefault}"

    parameters = "Unknown" if parameters == ""
    "PARAMETERS: #{parameters}\n"

  _describeJobHealthReport: (healthReport) =>
    result = ""
    if healthReport.length > 0
      for report in healthReport
        result += "\n  #{report.description}"
    else
      result = " unknown"

    "HEALTH: #{result}\n"

  _getJob: (escape = false) =>
    job = @msg.match[1].trim()

    # if the provided name is an alias, provide it's mapped job name
    aliases = @_getSavedAliases()
    job     = aliases[job] if aliases[job]

    if escape then @_querystring.escape(job) else job

  # Switch the index with the job name
  _getJobById: =>
    @_jobList[parseInt(@msg.match[1]) - 1]

  _getSavedAliases: =>
    aliases = @robot.brain.get('jenkins_aliases')
    aliases ||= {}
    aliases

  _lastBuildStatus: (lastBuild) =>
    job = @_getJob()
    server = @_serverManager.getServerByJobName(job)
    path = "job/#{job}/#{lastBuild.number}/api/json"
    @_requestFactorySingle server, path, @_handleLastBuildStatus

  _requestFactorySingle: (server, endpoint, callback, method = "get") =>
    user = server.auth.split(":")
    if server.url.indexOf('https') == 0 then http = 'https://' else http = 'http://'
    url = server.url.replace /^https?:\/\//, ''
    path = "#{http}#{user[0]}:#{user[1]}@#{url}/#{endpoint}"
    request = @msg.http(path)
    @_configureRequest request, server
    request[method]() ((err, res, body) -> callback(err, res, body, server))

  _requestFactory: (endpoint, callback, method = "get") =>
    for server in @_serverManager.listServers()
      @_requestFactorySingle server, endpoint, callback, method

  _setJob: (job) =>
    @msg.match[1] = job


  # Handlers
  # --------

  _handleBuild: (err, res, body, server) =>
    if err
      @reply err
    else if 200 <= res.statusCode < 400 # Or, not an error code.
      job     = @_getJob(true)
      jobName = @_getJob(false)
      @reply "(#{res.statusCode}) Build started for #{jobName} #{server.url}/job/#{job}"
    else if 400 == res.statusCode
      @build true
    else
      @reply "Status #{res.statusCode} #{body}"

  _handleDescribe: (err, res, body, server) =>
    if err
      @send err
      return

    try
      content = JSON.parse(body)
      @send @_describeJob(content)

      # Handle previous build status if there is one
      @_lastBuildStatus content.lastBuild if content.lastBuild
    catch error
      @send error

  _handleLast: (err, res, body, server) =>
    if err
      @send err
      return

    try
      content = JSON.parse(body)
      response = ""
      response += "NAME: #{content.fullDisplayName}\n"
      response += "URL: #{content.url}\n"
      response += "DESCRIPTION: #{content.description}\n" if content.description
      response += "BUILDING: #{content.building}\n"
      @send response
    catch error
      @send error

  _handleLastBuildStatus: (err, res, body, server) =>
    if err
      @send err
      return

    try
      response = ""
      content = JSON.parse(body)
      jobstatus = content.result || 'PENDING'
      jobdate = new Date(content.timestamp);
      response += "LAST JOB: #{jobstatus}, #{jobdate}\n"

      @send response
    catch error
      @send error

  _handleList: (err, res, body, server) =>
    @_processListResult err, res, body, server

  _handleListInit: (err, res, body, server) =>
    @_processListResult err, res, body, server, false

  _processListResult: (err, res, body, server, print = true) =>
    if err
      @send err
      return

    try
      content = JSON.parse(body)
      @_addJobsToJobsList content.jobs, server, print
      @_initComplete() if @_serverManager.hasInitialized()
    catch error
      @send error


module.exports = (robot) ->

  # Factories
  # ---------

  _serverManager = null
  serverManagerFactory = (msg) ->
    _serverManager = new JenkinsServerManager(msg) if not _serverManager
    _serverManager.setMessage msg
    _serverManager

  _plugin = null
  pluginFactory = (msg) ->
    _plugin = new HubotJenkinsPlugin(msg, serverManagerFactory(msg)) if not _plugin
    _plugin.setMessage msg
    _plugin.setRobot robot
    _plugin


  # Command Configuration
  # ---------------------

  robot.respond /j(?:enkins)? aliases/i, id: 'jenkins.aliases', (msg) ->
    pluginFactory(msg).listAliases()

  robot.respond /j(?:enkins)? build ([\w\.\-_ ]+)(, (.+))?/i, id: 'jenkins.build', (msg) ->
    pluginFactory(msg).build false

  robot.respond /j(?:enkins)? b (\d+)(, (.+))?/i, id: 'jenkins.b', (msg) ->
    pluginFactory(msg).buildById()

  robot.respond /j(?:enkins)? list( (.+))?/i, id: 'jenkins.list', (msg) ->
    pluginFactory(msg).list()

  robot.respond /j(?:enkins)? describe (.*)/i, id: 'jenkins.describe', (msg) ->
    pluginFactory(msg).describe()
	
  robot.respond /j(?:enkins)? d (\d+)/i, id: 'jenkins.d', (msg) ->
    pluginFactory(msg).describeById()

  robot.respond /j(?:enkins)? getAlias (.*)/i, id: 'jenkins.getAlias', (msg) ->
    pluginFactory(msg).getAlias()

  robot.respond /j(?:enkins)? last (.*)/i, id: 'jenkins.last', (msg) ->
    pluginFactory(msg).last()

  robot.respond /j(?:enkins)? l (\d+)/i, id: 'jenkins.l', (msg) ->
    pluginFactory(msg).lastById()

  robot.respond /j(?:enkins)? servers/i, id: 'jenkins.servers', (msg) ->
    pluginFactory(msg).servers()

  robot.respond /j(?:enkins)? setAlias (.*), (.*)/i, id: 'jenkins.setAlias', (msg) ->
    pluginFactory(msg).setAlias()
	
  robot.respond /j(?:enkins)? remAlias (.*)/i, id: 'jenkins.remAlias', (msg) ->
    pluginFactory(msg).remAlias()

  robot.jenkins =
    aliases:  ((msg) -> pluginFactory(msg).listAliases())
    build:    ((msg) -> pluginFactory(msg).build())
    describe: ((msg) -> pluginFactory(msg).describe())
    getAlias: ((msg) -> pluginFactory(msg).getAlias())
    last:     ((msg) -> pluginFactory(msg).last())
    list:     ((msg) -> pluginFactory(msg).list())
    servers:  ((msg) -> pluginFactory(msg).servers())
    setAlias: ((msg) -> pluginFactory(msg).setAlias())
    remAlias: ((msg) -> pluginFactory(msg).remAlias())
