# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# These enable behaviors that will become the default in the next major
# version of Ash. Setting them now opts your application into the new
# behavior and ensures a seamless upgrade. See the backwards compatibility
# guide for an explanation of each setting:
# https://hexdocs.pm/ash/backwards-compatibility-config.html
config :ash,
  allow_forbidden_field_for_relationships_by_default: true,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false],
  keep_read_action_loads_when_loading?: false,
  default_actions_require_atomic?: true,
  read_action_after_action_hooks_in_order?: true,
  bulk_actions_default_to_errors?: true,
  transaction_rollback_on_error?: true,
  redact_sensitive_values_in_errors?: true,
  default_string_length_count: :codepoints,
  infer_generic_action_reactors?: false,
  many_to_many_destroy_destination_on_match?: true,
  known_types: [AshPostgres.Timestamptz, AshPostgres.TimestamptzUsec, AshMoney.Types.Money],
  custom_types: [money: AshMoney.Types.Money]

config :spark,
  formatter: [
    remove_parens?: true,
    "Ash.Resource": [
      section_order: [
        :admin,
        :authentication,
        :token,
        :user_identity,
        :postgres,
        :resource,
        :code_interface,
        :actions,
        :policies,
        :pub_sub,
        :preparations,
        :changes,
        :validations,
        :multitenancy,
        :attributes,
        :relationships,
        :calculations,
        :aggregates,
        :identities
      ]
    ],
    "Ash.Domain": [
      section_order: [:admin, :resources, :policies, :authorization, :domain, :execution]
    ]
  ]

config :zippiker,
  ecto_repos: [Zippiker.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  ash_domains: [
    Zippiker.Accounts,
    Zippiker.Extensibility,
    Zippiker.Parties,
    Zippiker.Catalog,
    Zippiker.Crm,
    Zippiker.Sales,
    Zippiker.Accounting,
    Zippiker.Inventory,
    Zippiker.Purchasing,
    Zippiker.HR,
    Zippiker.Workflow,
    Zippiker.Expenses,
    Zippiker.Manufacturing,
    Zippiker.Portal,
    Zippiker.Compliance,
    Zippiker.Platform
  ]

config :ex_money, auto_start_exchange_rate_service: false

# Background jobs. Cron: leave accruals daily, overdue leave reviews hourly.
config :zippiker, Oban,
  engine: Oban.Engines.Basic,
  repo: Zippiker.Repo,
  queues: [default: 10, hr: 5],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 7 * 24 * 60 * 60},
    {Oban.Plugins.Cron,
     crontab: [
       {"15 0 * * *", Zippiker.HR.Workers.RunAccruals},
       {"5 * * * *", Zippiker.HR.Workers.ReviewOverdueLeave},
       {"30 0 * * *", Zippiker.Compliance.Workers.RefreshCalendars}
     ]}
  ]

# Where uploaded files (e.g. leave attachments) are stored.
config :zippiker, :uploads_dir, "priv/uploads"

# Configure the endpoint
config :zippiker, ZippikerWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ZippikerWeb.ErrorHTML, json: ZippikerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Zippiker.PubSub,
  live_view: [signing_salt: "mrZqVUij"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :zippiker, Zippiker.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  zippiker: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.0",
  zippiker: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
