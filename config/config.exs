# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

if Mix.env in [:dev, :prod, :test] do
    import_config "#{Mix.env}.exs"
end
