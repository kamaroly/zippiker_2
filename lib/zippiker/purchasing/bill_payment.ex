defmodule Zippiker.Purchasing.BillPayment do
  @moduledoc "Money paid to a supplier against an approved bill."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Purchasing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Purchasing.BillPayment.Attributes,
      Zippiker.Purchasing.BillPayment.Relationships,
      Zippiker.Purchasing.BillPayment.Actions,
      Zippiker.Purchasing.BillPayment.Policies
    ]

  postgres do
    table "bill_payments"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :bill, on_delete: :restrict
      reference :recorded_by, on_delete: :nilify
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end
end
