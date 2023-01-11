import Config

# Add configuration that is only needed when running on the host here.

config :logger, :console,
  level: :debug,
  metadata: [:session, :module, :function]
