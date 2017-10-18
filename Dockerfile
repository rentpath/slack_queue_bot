FROM elixir:1.5.2

ENV HOME=/home/elixir MIX_ENV=prod
RUN groupadd -r elixir && useradd -r -g elixir --create-home elixir

WORKDIR $HOME/slack_queue_bot
RUN mix local.hex --force
RUN mix local.rebar --force

COPY . $HOME/slack_queue_bot
RUN chown -R elixir:elixir $HOME/slack_queue_bot

USER elixir
EXPOSE 4000

RUN mix deps.get
ENTRYPOINT mix run --no-halt
