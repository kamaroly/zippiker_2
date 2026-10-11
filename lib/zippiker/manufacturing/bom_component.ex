defmodule Zippiker.Manufacturing.BomComponent do
  @moduledoc "A component of a bill of materials and the quantity used per batch."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Manufacturing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Manufacturing.BomComponent.Attributes,
      Zippiker.Manufacturing.BomComponent.Relationships,
      Zippiker.Manufacturing.BomComponent.Actions,
      Zippiker.Manufacturing.WorkCenter.Policies
    ]

  postgres do
    table "bom_components"
    repo Zippiker.Repo

    references do
      reference :bom, on_delete: :delete
      reference :product, on_delete: :restrict
    end
  end

  multitenancy do
    strategy :context
  end
end
