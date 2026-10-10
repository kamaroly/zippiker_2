defmodule Zippiker.Extensibility.CustomFieldDefinition.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :organization, Zippiker.Accounts.Organization do
      allow_nil? false
    end
  end
end
