defmodule Zippiker.Platform.AuditEvent.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :actor, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :organization, Zippiker.Accounts.Organization do
      public? true
      domain Zippiker.Accounts
    end

    belongs_to :target_user, Zippiker.Accounts.User do
      public? true
      domain Zippiker.Accounts
    end
  end
end
