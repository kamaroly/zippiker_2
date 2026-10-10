defmodule Zippiker.Platform.Plan do
  @moduledoc """
  A price list entry: per-seat monthly price, seat limit and the modules it
  includes. Changing a workspace's plan copies modules and seat limit onto
  the workspace.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Platform,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Platform.Plan.Attributes,
      Zippiker.Platform.Plan.Actions,
      Zippiker.Platform.Plan.Policies
    ]

  postgres do
    table "plans"
    repo Zippiker.Repo

    migration_defaults modules:
                         "fragment(\"ARRAY['crm', 'sales', 'purchasing', 'inventory', 'accounting', 'hr']::text[]\")"

    identity_wheres_to_sql one_default: "\"default?\" = true"
  end

  identities do
    identity :unique_code, [:code]
    identity :one_default, [:default?], where: expr(default? == true)
  end
end
