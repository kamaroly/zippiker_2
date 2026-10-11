defmodule Zippiker.Inventory.Warehouse.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    read :list do
      argument :active_only?, :boolean, default: false
      filter expr(^arg(:active_only?) == false or active? == true)
      prepare build(sort: [default?: :desc, name: :asc])
    end

    create :create do
      change Zippiker.Accounts.Changes.SetBranch
      primary? true
      accept [:name, :code, :address, :default?, :branch_id]
      change Zippiker.Inventory.Warehouse.Changes.SingleDefault
    end

    update :update do
      primary? true
      accept [:name, :code, :address, :default?, :active?, :branch_id]
      require_atomic? false
      change Zippiker.Inventory.Warehouse.Changes.SingleDefault
    end

    action :default, :struct do
      description "The default warehouse, created as \"Main warehouse\" if there is none."
      constraints instance_of: Zippiker.Inventory.Warehouse
      run Zippiker.Inventory.Warehouse.Actions.Default
    end
  end
end
