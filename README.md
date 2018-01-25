# ci-pipeline-client
Cross-Cloud CI client for interacting with the build, provision and app deploy CI pipeline

## Setup

Create .env

Add gitlab API tokens

Choose the running environment for the Cross-Cloud CI system: eg. `development`, `staging`, `production`. Example
  * export CROSS_CLOUD_CI_ENV="development"

which will instruct the the trigger client to load settings for that environment such as the GitLab API endpoint URL

## Running the trigger client

TBD

See [usage from IRB](docs/usage_from_irb.mkd)

### From cron

Create a crontab entry like so:

```
SHELL=/bin/bash
CROSS_CLOUD_CI_ENV="production"
CROSSCLOUDCI_TRIGGER_WORKDIR="/home/pair/src/wolfpack/cncf/crosscloudci-trigger"
0 3 * * * CROSSCLOUDCI_TRIGGER_LOGFILE="crosscloudci_trigger-`date +\%Y\%m\%d-\%H:\%M:\%S\%z`.log" && $CROSSCLOUDCI_TRIGGER_WORKDIR/bin/crontrigger build_and_deploy > "$CROSSCLOUDCI_TRIGGER_WORKDIR/logs/$CROSSCLOUDCI_TRIGGER_LOGFILE" 2>&1
```




