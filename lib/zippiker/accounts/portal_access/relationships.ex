defmodule Zippiker.Accounts.PortalAccess.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization, allow_nil?: false, public?: true
    belongs_to :user, Zippiker.Accounts.User, public?: true
    belongs_to :invited_by, Zippiker.Accounts.User, public?: true
  end
end
