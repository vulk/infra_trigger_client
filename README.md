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

