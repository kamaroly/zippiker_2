defmodule Zippiker.Manufacturing.BomOperation do
  @moduledoc "A step in making the product: what's done, where, and how long it takes per batch."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Manufacturing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Manufacturing.BomOperation.Attributes,
      Zippiker.Manufacturing.BomOperation.Relationships,
      Zippiker.Manufacturing.BomOperation.Actions,
      Zippiker.Manufacturing.WorkCenter.Policies
    ]

  postgres do
    table "bom_operations"
    repo Zippiker.Repo

    references do
      reference :bom, on_delete: :delete
      reference :work_center, on_delete: :restrict
    end
  end

  multitenancy do
    strategy :context
  end
end
