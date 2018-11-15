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
#   hubot jenkins b <jobNumber>&<params> - builds the job specified by jobNumber with parameters as key=value&key2=value2. List jobs to get number.
#   hubot jenkins build <job|alias|job folder/job> - builds the specified Jenkins job
#   hubot jenkins build <job|alias|job folder/job>&<params> - builds the specified Jenkins job with parameters as key=value&key2=value2
#   hubot jenkins d <jobNumber> - Describes the job specified by jobNumber. List jobs to get number.
#   hubot jenkins describe <job|alias|job folder/job> - Describes the specified Jenkins job
#   hubot jenkins getAlias <name> - Retrieve value of job name alias
#   hubot jenkins list <filter> - lists Jenkins jobs grouped by server
#   hubot jenkins l <jobNumber> - Details about the last build for the job specified by jobNumber. List jobs to get number.
#   hubot jenkins last <job|alias|job folder/job> - Details about the last build for the specified Jenkins job
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
  _rootFolder: null
  _querystring: null

  constructor: (url, auth) ->
    @url = url
    @auth = auth
    @_querystring = require 'querystring'
    @activeRequests = 0

  hasInitialized: ->
    @_hasListed

  hasActiveRequests: ->
    @activeRequests > 0

  getJobs: =>
    @_rootFolder.getJobs()

  hasJobs: =>
    @getJobs().length > 0

  setFolder: (folder) =>
    @_hasListed = true
    @_rootFolder = folder

  getFolder: =>
    @_rootFolder

  hasFolder: =>
    true if @_rootFolder

  getFolderByName: (folderName) =>
    @_rootFolder.getFolderByName(folderName)

  hasFolderByName: (folderName) =>
    @_rootFolder.hasFolderByName(folderName)

  getJobByName: (jobName) =>
    @_rootFolder.getJobByName(jobName)

  hasFolderByName: (jobName) =>
    @_rootFolder.hasJobByName(jobName)

class JenkinsFolder
  name: null
  path: null
  depth: null
  _jobs: null
  _folders: null
  _querystring: null

  constructor: (name, path, depth) ->
    @name = name
    @path = path
    @depth = depth
    @_jobs = []
    @_folders = []
    @_querystring = require 'querystring'

  hasInitialized: ->
    @_hasListed

  addJob: (job) =>
    @_hasListed = true
    @_jobs.push job if not @hasJobByName(job.name, false)

  getJobs: (recursive=true) =>
    res = @_jobs
    if (recursive)
      for subFolder in @getFolders(false)
        res = res.concat(subFolder.getJobs())
    return res

  hasJobs: =>
    @getJobs().length > 0

  getJobByName: (jobName, recursive=true) =>
    jobName = @_querystring.unescape(jobName).trim()
    jobs = @_jobs.where(name: jobName)
    # otherwise we must start searching the other folders
    if (recursive)
      for subFolder in @_folders
        subJobs = subFolder.getJobByName(jobName)
        jobs = jobs.concat(subJobs)
    jobs

  hasJobByName: (jobName, recursive=true) =>
    @getJobByName(jobName, recursive).length > 0

  addFolder: (folder) =>
    @_hasListed = true
    @_folders.push folder if not @hasFolderByName(folder.name, false)

  getFolders: (recursive=true) =>
    res = @_folders.sort((a,b) => true if (a.name > b.name))
    if (recursive)
      for subFolder in @getFolders(false)
        res = res.concat(subFolder.getFolders())
    return res

  hasFolders: =>
    @getFolders().length > 0

  getFolderByName: (folderName, recursive=true) =>
    folderName = @_querystring.unescape(folderName).trim()
    folders = @_folders.where(name: folderName)
    if (recursive)
      for subFolder in @_folders
        subFolders = subFolder.getFolderByName(folderName)
        folders = folders.concat(subFolders)
    folders

  hasFolderByName: (folderName, recursive=true) =>
    @getFolderByName(folderName, recursive).length > 0

class JenkinsJob
  name: null
  path: null
  state: null

  constructor: (name, path, state) ->
    @name = name
    @path = path
    @state = state


class JenkinsServerManager extends HubotMessenger
  _servers: []

  constructor: (msg) ->
    super msg
    @_loadConfiguration()

  getServerByJobName: (jobName) =>
    @send "ERROR: Make sure to run a 'list' to update the job cache" if not @serversHaveJobs()
    for server in @_servers
      return server if server.getFolder().hasJobByName(jobName)
    null

  hasInitialized: =>
    for server in @_servers
      return false if not server.hasInitialized()
    true

  hasActiveRequests: =>
    for server in @_servers
      return true if server.hasActiveRequests()
    false

  listServers: =>
    @_servers

  serversHaveJobs: =>
    for server in @_servers
      return true if server.hasJobs()
    false

  servers: =>
    for server in @_servers
      message = "#{server.url}\n"
      message += @_serversSubFoldersAndJobs(server, server.getFolder())
      @send message
  
  _serversSubFoldersAndJobs: (server, folder) =>
    response = ""
    # add the current folder's jobs first
    for job in folder.getJobs(false)
      response += "-".repeat(folder.depth+1)+" #{job.name}\n"
    # add the sub folder's jobs and folders
    for subFolder in folder.getFolders(false)
      response += "-".repeat(folder.depth+1)+" #{subFolder.name}\n"+@_serversSubFoldersAndJobs(server, subFolder)
    response

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
  _folderList: []
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
    job = @_getJob()
    if not job
      return
    server = @_serverManager.getServerByJobName(job.name)
    command = if buildWithEmptyParameters then "buildWithParameters" else "build"
    path = if @_params then "#{job.path}/buildWithParameters?#{@_params}" else "#{job.path}/#{command}"
    if !server
      @msg.send "I couldn't find any servers with a job called #{job.name}.  Try `jenkins servers` to get a list."
      return
    @_requestFactorySingle server, null, path, @_handleBuild, "post"

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
    job = @_getJob()
    if not job
      return
    server = @_serverManager.getServerByJobName(job.name)
    if !server
      @msg.send "I couldn't find any servers with a job called #{job.name}.  Try `jenkins servers` to get a list."
      return
    @_requestFactorySingle server, null, "#{job.path}/api/json", @_handleDescribe

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
    if not job
      return
    server = @_serverManager.getServerByJobName(job.name)
    path = "#{job.path}/lastBuild/api/json"
    if !server
      @msg.send "I couldn't find any servers with a job called #{job.name}.  Try `jenkins servers` to get a list."
      return
    @_requestFactorySingle server, null, path, @_handleLast

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

  _makeRootFolderForServer: (items, server) =>
    response = ""
    server.activeRequests = 1
    # make the default/root level folder
    rootFolder = server.getFolder()
    if rootFolder == null
      rootFolder = new JenkinsFolder("Root", "", 0)
      server.setFolder(rootFolder)

    @_addJobsToFoldersList(items, server, rootFolder)

  _addJobsToFoldersList: (items, server, folder) =>
    jenkinsJobFolderType = ['jenkins.branch.OrganizationFolder','com.cloudbees.hudson.plugins.folder.Folder','org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject']    
    for item in items
      itemType = item._class
      if (itemType in jenkinsJobFolderType)
        newFolder = new JenkinsFolder(item.name, "#{folder.path}/job/#{@_querystring.escape(item.name)}", folder.depth+1)
        folder.addFolder(newFolder)
        server.activeRequests++
        @_requestFactorySingle server, newFolder, "#{newFolder.path}/api/json", @_handleNewFolder
      else
        newJob = new JenkinsJob(item.name, "#{folder.path}/job/#{@_querystring.escape(item.name)}", if item.color == "red" then "FAIL" else "PASS")
        folder.addJob(newJob)
    # count our current folder as processed
    server.activeRequests--
    # check if we are the last active instance
    if (not @_serverManager.hasActiveRequests())
      for server in @_serverManager.listServers()
        @_listJobs(server, server.getFolder(), true)
      @_initComplete() if @_serverManager.hasInitialized()
    

  _listJobs: (server, folder, isRoot=false) =>
    response = ""
    # go through each folder and list jobs first then other folders, sorted alphabetically for consistency
    for job in folder.getJobs(false)
      @_jobList.push(job) if @_jobList.indexOf(job) == -1
      response += "\t".repeat(folder.depth+2)+"[#{@_jobList.indexOf(job) + 1}] #{job.state} #{job.name}\n"
    for subFolder in folder.getFolders(false)
      response += "\t".repeat(subFolder.depth+1)+"Folder: #{subFolder.name}\n" if subFolder.name != ""
      response += @_listJobs(server, subFolder)
    if isRoot
      if @_outputStatus
        @send "Server: #{server.url}\n#{response}"
    else 
      return response

  _configureRequest: (request, server = null) =>
    defaultAuth = process.env.HUBOT_JENKINS_AUTH
    return if not server and not defaultAuth
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

  _getJob: =>
    job = null
    if (typeof(@msg.match[1]) == "object")
	  # check if its a job we already stored
      job = @msg.match[1]
    else
      # check if the user gave us a folder path to follow and a job
      if (@msg.match[1].indexOf("/") != -1)
        folderPath = @msg.match[1].split("/")
        jobName = folderPath[folderPath.length-1]
        folderPath.splice(folderPath.length-1, 1)

        if (folderPath.length == 1)
          # when we only receive the folder name
          job = @_getJobByFolderName(folderPath[0], jobName)
          if (!job)
            @send "There are no folders with the name #{folderPath[0]} that have a job called #{jobName}."
        else
          # when we receive the absolute path to the job
          job = @_getJobByAbsolutePath(folderPath, jobName)
          if (!job)
            @send "There are no folders with the path #{folderPath.join('/')} that have a job called #{jobName}."
      else
        # when we receive no folder information at all and only the job name
        job = @_getJobByName(@msg.match[1].trim())
    job

  _getJobByFolders: (folders, jobName) =>
    # find all jobs that are in the folders given, this is based off the presumption that all of the folders have the same name and some may/may not have the job we're searching for
    jobs = []
    for folder in folders
      # only search for jobs in the current folder's directory, otherwise we risk duplicates
      jobs = jobs.concat(folder.getJobByName(jobName, false))
    if (jobs.length > 1)
      # we're safe to just use the first one, as they should all have the same name
      @send "There are multiple folders with the name #{folders[0].name} that have a job called #{jobName}.  Please use `jenkins list` and an ID instead."
    else if (jobs.length == 1)
      return jobs[0] 
    # no else case because there aren't any folders to pull a name from	to send a message to the user 
    null

  _getJobByFolderName: (folderName, jobName) =>
    # find all of the folders that have this name
    folders = []
    for server in @_serverManager.listServers()
      if (folderName == "")
        # if the folder name is empty, presume they're referencing the root folder
        folders.push(server.getFolder())
      else
        folders = folders.concat(server.getFolderByName(folderName))
    # find all possible jobs that match in all given folders
    @_getJobByFolders(folders, jobName)

  _getJobByAbsolutePath: (folderPath, jobName) =>
    # find all folders that have this path
    folders = []
    for server in @_serverManager.listServers()
      curFolder = server.getFolder()
      for folderName in folderPath
        # this should either be of length 1 or length 0, as there cannot be two subfolders with the same name (in iterative mode)
        nextFolder = curFolder.getFolderByName(folderName, false)
        if (nextFolder.length == 1)
          curFolder = nextFolder[0]
        else
          curFolder = null
          break
      # check if we found a folder
      if (curFolder)
        folders.push(curFolder)
    # now find all possible jobs
    @_getJobByFolders(folders, jobName)

  _getJobByName: (jobName) =>
    # if the provided name is an alias, provide it's mapped job name
    aliases = @_getSavedAliases()
    jobName = aliases[jobName] if aliases[jobName]
	
    jobs = []
    # perform lookup
    for server in @_serverManager.listServers()
      job = server.getJobByName(jobName)
      if job.length > 0
        jobs = jobs.concat(job)
    if jobs.length > 1
      @send "There are multiple jobs with that name, please use an id from `jenkins list` instead or a folder path."
    else if jobs.length == 1
      return jobs[0] 
    else
      @send "There are no jobs with the name #{jobName}"
    null

  # Switch the index with the job name
  _getJobById: =>
    @_jobList[parseInt(@msg.match[1]) - 1]

  _getSavedAliases: =>
    aliases = @robot.brain.get('jenkins_aliases')
    aliases ||= {}
    aliases

  _lastBuildStatus: (lastBuild) =>
    job = @_getJob()
    server = @_serverManager.getServerByJobName(job.name)
    path = "#{job.path}/#{lastBuild.number}/api/json"
    @_requestFactorySingle server, null, path, @_handleLastBuildStatus

  _requestFactorySingle: (server, folder, endpoint, callback, method = "get") =>
    user = server.auth.split(":")
    if server.url.indexOf('https') == 0 then http = 'https://' else http = 'http://'
    url = server.url.replace /^https?:\/\//, ''
    path = "#{http}#{user[0]}:#{user[1]}@#{url}/#{endpoint}"
    request = @msg.http(path)
    @_configureRequest request, server
    request[method]() ((err, res, body) -> callback(err, res, body, server, folder))

  _requestFactory: (endpoint, callback, method = "get") =>
    for server in @_serverManager.listServers()
      @_requestFactorySingle server, server.getFolder(), endpoint, callback, method

  _setJob: (job) =>
    @msg.match[1] = job


  # Handlers
  # --------
  _handleNewFolder: (err, res, body, server, folder) =>
    if err
      @send "It appears an error occurred while contacting your Jenkins instance.  The error I received was #{err.code} from #{server.url}.  Please verify that your Jenkins instance is configured properly."
      return

    try
      content = JSON.parse(body)
      @_addJobsToFoldersList content.jobs, server, folder
    catch error
      @send error

  _handleBuild: (err, res, body, server, folder) =>
    if err
      @reply "It appears an error occurred while contacting your Jenkins instance.  The error I received was #{err.code} from #{server.url}.  Please verify that your Jenkins instance is configured properly."
    else if 200 <= res.statusCode < 400 # Or, not an error code.
      job = @_getJob(false)
      @reply "(#{res.statusCode}) Build started for #{job.name} #{server.url}/#{job.path}"
    else if 400 == res.statusCode
      @build true
    else
      @reply "Status #{res.statusCode} #{body}"

  _handleDescribe: (err, res, body, server, folder) =>
    if err
      @send "It appears an error occurred while contacting your Jenkins instance.  The error I received was #{err.code} from #{server.url}.  Please verify that your Jenkins instance is configured properly."
      return

    try
      content = JSON.parse(body)
      @send @_describeJob(content)

      # Handle previous build status if there is one
      @_lastBuildStatus content.lastBuild if content.lastBuild
    catch error
      @send error

  _handleLast: (err, res, body, server, folder) =>
    if err
      @send "It appears an error occurred while contacting your Jenkins instance.  The error I received was #{err.code} from #{server.url}.  Please verify that your Jenkins instance is configured properly."
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

  _handleLastBuildStatus: (err, res, body, server, folder) =>
    if err
      @send "It appears an error occurred while contacting your Jenkins instance.  The error I received was #{err.code} from #{server.url}.  Please verify that your Jenkins instance is configured properly."
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

  _handleList: (err, res, body, server, folder) =>
    @_processListResult err, res, body, server

  _handleListInit: (err, res, body, server, folder) =>
    @_processListResult err, res, body, server, false

  _processListResult: (err, res, body, server, print = true) =>
    if err
      @send "It appears an error occurred while contacting your Jenkins instance.  The error I received was #{err.code} from #{server.url}.  Please verify that your Jenkins instance is configured properly."
      return

    try
      content = JSON.parse(body)
      @_outputStatus = print
      @_makeRootFolderForServer content.jobs, server
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

  robot.respond /j(?:enkins)? build ([^&]+)(&\s?(.+))?/i, id: 'jenkins.build', (msg) ->
    pluginFactory(msg).build false

  robot.respond /j(?:enkins)? b (\d+)(&\s?(.+))?/i, id: 'jenkins.b', (msg) ->
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
