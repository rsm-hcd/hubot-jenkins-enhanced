# Hubot Jenkins Enhanced Plugin

Jenkins integration for Hubot with multiple server support with the use of access tokens instead of password authentication.

### Configuration
Auth should be in the "user:access-token" format.\
You can find your access token at $JENKINS_URL/me/configure

- ```HUBOT_JENKINS_URL```
- ```HUBOT_JENKINS_AUTH```
- ```HUBOT_JENKINS_{1-N}_URL```
- ```HUBOT_JENKINS_{1-N}_AUTH```

### Commands
- ```hubot jenkins aliases``` - lists all saved job name aliases **
- ```hubot jenkins b <jobNumber>``` - builds the job specified by jobNumber. List jobs to get number.
- ```hubot jenkins b <jobNumber>&<params>``` - builds the job specified by jobNumber with parameters as key=value&key2=value2. List jobs to get number.
- ```hubot jenkins build <job|alias|job folder/job>``` - builds the specified Jenkins job
- ```hubot jenkins build <job|alias|job folder/job>&<params>``` - builds the specified Jenkins job with parameters as key=value&key2=value2
- ```hubot jenkins d <jobNumber>``` - Describes the job specified by jobNumber. List jobs to get number.
- ```hubot jenkins describe <job|alias|job folder/job>``` - Describes the specified Jenkins job
- ```hubot jenkins getAlias <name>``` - Retrieve value of job name alias **
- ```hubot jenkins l <jobNumber>``` - Details about the last build for the job specified by jobNumber. List jobs to get number.
- ```hubot jenkins last <job|alias|job folder/job>``` - Details about the last build for the specified Jenkins job
- ```hubot jenkins list <filter>``` - lists Jenkins jobs grouped by server
- ```hubot jenkins servers``` - Lists known jenkins servers
- ```hubot jenkins setAlias <name>, <value>``` - creates job name alias **
- ```hubot jenkins remAlias <name>``` - removes job name alias **

**Notes:** 
- Job Folder/Job can be either the absolute path to the job or the folder containing the job. \
For example, `hubot jenkins describe The Path/To/My/Job/The Job To Run` or `hubot jenkins describe Job/The Job To Run`

### Persistence **
Note: Various features will work best if the Hubot brain is configured to be persisted. By default
the brain is an in-memory key/value store, but it can easily be configured to be persisted with Redis so
data isn't lost when the process is restarted.

@See [Hubot Scripting](https://hubot.github.com/docs/scripting/) for more details
