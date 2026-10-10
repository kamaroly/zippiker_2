defmodule Zippiker.Crm.Pipeline.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
      domain Zippiker.Accounts
    end

    has_many :stages, Zippiker.Crm.Stage do
      public? true
      sort position: :asc
    end
  end
end
