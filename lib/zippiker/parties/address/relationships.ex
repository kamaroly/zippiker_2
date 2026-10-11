defmodule Zippiker.Parties.Address.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :party, Zippiker.Parties.Party do
      allow_nil? false
      public? true
    end
  end
end
