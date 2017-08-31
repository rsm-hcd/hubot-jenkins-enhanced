# Hubot Jenkins Enhanced Plugin

Jenkins integration for Hubot with multiple server support


### Configuration
Auth should be in the "user:password" format encode with base64.

- ```HUBOT_JENKINS_URL```
- ```HUBOT_JENKINS_AUTH```
- ```HUBOT_JENKINS_CRUMB```
- ```HUBOT_JENKINS_{1-N}_URL```
- ```HUBOT_JENKINS_{1-N}_AUTH```



### Commands
- ```hubot jenkins aliases``` - lists all saved job name aliases **
- ```hubot jenkins b <jobNumber>``` - builds the job specified by jobNumber. List jobs to get number.
- ```hubot jenkins build <job|alias>``` - builds the specified Jenkins job
- ```hubot jenkins build <job|alias>, <params>``` - builds the specified Jenkins job with parameters as key=value&key2=value2
- ```hubot jenkins describe <job|alias>``` - Describes the specified Jenkins job
- ```hubot jenkins getAlias <name>``` - Retrieve value of job name alias **
- ```hubot jenkins last <job|alias>``` - Details about the last build for the specified Jenkins job
- ```hubot jenkins list <filter>``` - lists Jenkins jobs grouped by server
- ```hubot jenkins servers``` - Lists known jenkins servers
- ```hubot jenkins setAlias <name>, <value>``` - creates job name alias **

### Persistence **
Note: Various features will work best if the Hubot brain is configured to be persisted. By default
the brain is an in-memory key/value store, but it can easily be configured to be persisted with Redis so
data isn't lost when the process is restarted.

@See [Hubot Scripting](https://hubot.github.com/docs/scripting/) for more details
