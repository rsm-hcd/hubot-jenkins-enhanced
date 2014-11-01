# Hubot Jenkins Enhanced Plugin

Jenkins integration for Hubot with multiple server support


### Configuration
- HUBOT_JENKINS_URL
- HUBOT_JENKINS_AUTH
- HUBOT_JENKINS_{1-N}_URL
- HUBOT_JENKINS_{1-N}_AUTH

    - Auth should be in the "user:password" format.

### Commands
- ```hubot jenkins b <jobNumber>``` - builds the job specified by jobNumber. List jobs to get number.
- ```hubot jenkins build <job>``` - builds the specified Jenkins job
- ```hubot jenkins build <job>, <params>``` - builds the specified Jenkins job with parameters as key=value&key2=value2
- ```hubot jenkins list <filter>``` - lists Jenkins jobs grouped by server
- ```hubot jenkins describe <job>``` - Describes the specified Jenkins job
- ```hubot jenkins last <job>``` - Details about the last build for the specified Jenkins job
- ```hubot jenkins servers``` - Lists known jenkins servers
