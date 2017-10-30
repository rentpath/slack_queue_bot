FROM elixir:1.5.2

ENV HOME=/home/elixir MIX_ENV=prod
RUN groupadd -r elixir && useradd -r -g elixir --create-home elixir

WORKDIR $HOME/slack_queue_bot
RUN mix local.hex --force
RUN mix local.rebar --force

RUN mkdir -p $HOME/slack_queue_bot/data

RUN mkdir -p $HOME/.cache
RUN chown -R elixir:elixir $HOME/.cache
RUN apt-get update
RUN apt-get -y install python2.7 python2.7-dev curl
RUN curl -O https://bootstrap.pypa.io/get-pip.py
RUN python2.7 get-pip.py
RUN pip install awscli --upgrade --user

COPY . $HOME/slack_queue_bot
RUN chown -R elixir:elixir $HOME/slack_queue_bot

USER elixir
EXPOSE 4000

RUN mix deps.get
ENTRYPOINT mix run --no-halt
