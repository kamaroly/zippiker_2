defmodule Zippiker.Manufacturing.BillOfMaterials.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Manufacturing.BillOfMaterials.Validations

  @fields [:reference, :quantity, :notes, :active?]
  @loads [:product, components: [product: [:on_hand]], operations: [:work_center]]

  actions do
    defaults [:read]

    read :search do
      argument :product_id, :uuid
      argument :active_only?, :boolean, default: false
      filter expr(is_nil(^arg(:product_id)) or product_id == ^arg(:product_id))
      filter expr(^arg(:active_only?) == false or active? == true)
      prepare build(sort: [inserted_at: :desc], load: @loads)
    end

    create :create do
      primary? true
      accept [:product_id | @fields]
      argument :components, {:array, :map}, default: []
      argument :operations, {:array, :map}, default: []

      validate Validations.Producible
      validate Validations.HasComponents
      change manage_relationship(:components, type: :direct_control)
      change manage_relationship(:operations, type: :direct_control)
    end

    update :update do
      primary? true
      require_atomic? false
      accept @fields
      argument :components, {:array, :map}
      argument :operations, {:array, :map}

      validate Validations.HasComponents
      change manage_relationship(:components, type: :direct_control)
      change manage_relationship(:operations, type: :direct_control)
    end

    destroy :destroy do
      primary? true
    end
  end
end
