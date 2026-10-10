defmodule Zippiker.Manufacturing.BillOfMaterials do
  @moduledoc """
  The recipe for a product: the components (and quantities) that make
  `quantity` units of it, and the operations (minutes at a work center).
  Products can have several; production orders use the active one by default.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Manufacturing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Manufacturing.BillOfMaterials.Attributes,
      Zippiker.Manufacturing.BillOfMaterials.Relationships,
      Zippiker.Manufacturing.BillOfMaterials.Actions,
      Zippiker.Manufacturing.WorkCenter.Policies
    ]

  postgres do
    table "bills_of_materials"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :product, on_delete: :delete
    end

    custom_indexes do
      index [:organization_id, :product_id]
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end
end
