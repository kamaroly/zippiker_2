defmodule Zippiker.Accounting.Account do
  @moduledoc """
  A line in the chart of accounts. `system_key` marks the accounts automatic
  postings use (receivable, revenue, tax payable, cash…); those can be renamed
  and renumbered but not deleted.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Accounting,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Accounting.Account.Attributes,
      Zippiker.Accounting.Account.Relationships,
      Zippiker.Accounting.Account.Aggregates,
      Zippiker.Accounting.Account.Calculations,
      Zippiker.Accounting.Account.Actions,
      Zippiker.Accounting.Account.Policies
    ]

  postgres do
    table "accounts"
    repo Zippiker.Repo

    identity_wheres_to_sql unique_system_key: "system_key IS NOT NULL"

    references do
      reference :organization, on_delete: :delete
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  identities do
    identity :unique_code, [:code]
    identity :unique_system_key, [:system_key], where: expr(not is_nil(system_key))
  end
end
