defmodule Zippiker.Accounts.Organization do
  @moduledoc """
  A workspace. Its business records live in its own Postgres schema
  (`Zippiker.Accounts.Tenant`); the organization is the Ash tenant
  (`Ash.ToTenant` returns the schema, or the id for attribute tenants).
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Accounts.Organization.Attributes,
      Zippiker.Accounts.Organization.Relationships,
      Zippiker.Accounts.Organization.Aggregates,
      Zippiker.Accounts.Organization.Actions,
      Zippiker.Accounts.Organization.Policies
    ]

  postgres do
    table "organizations"
    repo Zippiker.Repo

    migration_defaults maker_checker_scopes: "fragment(\"ARRAY[]::text[]\")",
                       enabled_modules:
                         "fragment(\"ARRAY['crm', 'sales', 'purchasing', 'inventory', 'accounting', 'hr', 'expenses', 'manufacturing']::text[]\")"
  end

  identities do
    identity :unique_domain, [:domain]
    identity :unique_schema_name, [:schema_name]
  end
end
