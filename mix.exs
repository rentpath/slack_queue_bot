defmodule QueueBot.Mixfile do
  use Mix.Project

  def project do
    [
      app: :queue_bot,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [mod: {QueueBot, []}, extra_applications: [:logger]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [{:conform, "~> 2.5.2", runtime: false},
     {:cowboy, "~> 1.1.2"},
     {:distillery, "~> 1.5.2", runtime: false},
     {:exredis, ">= 0.2.4"},
     {:httpoison, "~> 0.13"},
     {:plug, "~> 1.4.0"},
     {:poison, "~> 2.0"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end
end
