defmodule Zippiker.Accounts.NumberSequence.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :legal_entity, Zippiker.Accounts.LegalEntity, allow_nil?: false, public?: true
  end
end
