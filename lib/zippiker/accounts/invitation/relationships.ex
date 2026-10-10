defmodule Zippiker.Accounts.Invitation.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization, allow_nil?: false, public?: true
    belongs_to :invited_by, Zippiker.Accounts.User, public?: true
  end
end
