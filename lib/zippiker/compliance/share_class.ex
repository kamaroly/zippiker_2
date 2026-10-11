defmodule Zippiker.Compliance.ShareClass do
  @moduledoc """
  A class of shares (Ordinary, Preference…) with its nominal value and rights.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Compliance,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Compliance.ShareClass.Attributes,
      Zippiker.Compliance.ShareClass.Relationships,
      Zippiker.Compliance.ShareClass.Actions,
      Zippiker.Compliance.Policies
    ]

  postgres do
    table "share_classes"
    repo Zippiker.Repo

    references do
      reference :profile, on_delete: :delete
    end
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :unique_name, [:profile_id, :name]
  end
end
