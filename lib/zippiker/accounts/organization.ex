defmodule Zippiker.Accounts.Organization do
  @moduledoc """
  A workspace. Every business record belongs to exactly one organization,
  which is used as the Ash tenant (`Ash.ToTenant` returns its id).
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

    migration_defaults enabled_modules:
                         "fragment(\"ARRAY['crm', 'sales', 'purchasing', 'inventory', 'accounting', 'hr', 'expenses', 'manufacturing']::text[]\")"
  end
end
