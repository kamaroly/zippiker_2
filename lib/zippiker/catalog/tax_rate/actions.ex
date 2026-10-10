defmodule Zippiker.Catalog.TaxRate.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read, :destroy]

    read :list do
      prepare build(sort: [default?: :desc, rate: :asc])
    end

    create :create do
      primary? true
      accept [:name, :rate, :default?]
    end

    update :update do
      primary? true
      accept [:name, :rate, :default?]
    end
  end
end
