defmodule Zippiker.Accounts.Branch do
  @moduledoc """
  A location of the business (head office, shops, depots). Documents,
  employees, warehouses and journal entries carry their branch, so reports
  can be run per branch. Every team has a default branch ("Head office");
  branch pickers show once the team turns on multiple branches.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Accounts.Branch.Attributes,
      Zippiker.Accounts.Branch.Relationships,
      Zippiker.Accounts.Branch.Actions,
      Zippiker.Accounts.LegalEntity.Policies
    ]

  postgres do
    table "branches"
    repo Zippiker.Repo
    identity_wheres_to_sql one_default: "\"default?\" = true"

    references do
      reference :manager, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :unique_code, [:code]
    identity :one_default, [:default?], where: expr(default? == true)
  end
end
