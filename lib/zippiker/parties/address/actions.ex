defmodule Zippiker.Parties.Address.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  @fields [:kind, :line1, :line2, :city, :region, :postal_code, :country]

  actions do
    defaults [:read, :destroy]

    read :for_party do
      argument :party_id, :uuid, allow_nil?: false
      filter expr(party_id == ^arg(:party_id))
      prepare build(sort: [inserted_at: :asc])
    end

    create :create do
      primary? true
      accept [:party_id | @fields]
    end

    update :update do
      primary? true
      accept @fields
    end
  end
end
