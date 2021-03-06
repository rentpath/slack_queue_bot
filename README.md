# QueueBot

This is a chat bot server intended to be used with slack to create and manage a queue.  I wasn't
a fan of the lack of features and custom ordering of the slack-wide `@reviewq` bot.

There is no database and no persistance.  Everything is in memory.  Once your server is halted,
crashes, etc, you lose all queues.  That may change in a future version.

## Installation

* `mix deps.get`
* `mix run --no-halt`

And then, inside slack configuration, "create a new app" for your organization.  You'll need to
fill in these two sections.  "your root endpoint" refers to the host and port on which you
just started this server.

* "Slash Commands"
  * "Create new command"
    * "Command": `/queue` or something similar
    * "Request URL": your root endpoint
    * "Short Description": `interface to the queue`
    * "Usage hint": `[help | display | edit | <new item>]`
* "Interactive Components"
  * "Request URL": your root endpoint
  * "Options Load URL (for Message Menus)": leave empty
* "OAuth & Permissions"
  * "Select Permission Scopes": `Send messages as <YourBotName>`
  * "OAuth Access Token": add this to config.exs (or an env-specific `Mix.Config` file)

You can also choose to utilize an access token fetcher, also in the `config.exs` file.  It's
advised not to store any secrets, such as this, in any git repo or public dockerhub image.

## Rentpath-specific

Note:
"Root Endpoint" above can be discovered with the ECS CLI.
`ecs-cli ps --cluster queuebot-cluster` 
to get the current IP/port running on AWS.

To start the service:

`ecs-cli compose --verbose --task-role-arn slack-queue-bot --cluster queuebot-cluster --region us-east-2 up`

To stop the service:

`ecs-cli compose --verbose --task-role-arn slack-queue-bot --cluster queuebot-cluster --region us-east-2 down`

The compose serializes the data between restarts using redis.  Assuming you do the above, and use the same
cluster/service/machine, you should get the same data on restart.
