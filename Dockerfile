FROM elixir:1.6.4

ENV HOME=/home/elixir MIX_ENV=prod
RUN groupadd -r elixir && useradd -r -g elixir --create-home elixir

RUN apt-get update
RUN apt-get -y install unzip python2.7 python2.7-dev

RUN mkdir -p $HOME/slack_queue_bot/data
WORKDIR $HOME/slack_queue_bot
RUN mix local.hex --force
RUN mix local.rebar --force

RUN chown -R elixir:elixir $HOME

RUN curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
RUN unzip awscli-bundle.zip
RUN ./awscli-bundle/install -b /bin/aws

COPY . $HOME/slack_queue_bot
RUN chown -R elixir:elixir $HOME

USER elixir
EXPOSE 4000

RUN mix deps.get
ENTRYPOINT mix run --no-halt
