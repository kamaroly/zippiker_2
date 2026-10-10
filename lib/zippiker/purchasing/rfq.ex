defmodule Zippiker.Purchasing.Rfq do
  @moduledoc """
  A request for quotation to a supplier (`RFQ-2026-0001`): draft → sent →
  quoted (the supplier answered; prices entered) → accepted / declined.
  Accepting turns it into a purchase order.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Purchasing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Purchasing.Rfq.Attributes,
      Zippiker.Purchasing.Rfq.Relationships,
      Zippiker.Purchasing.Rfq.Actions,
      Zippiker.Purchasing.PurchaseOrder.Policies
    ]

  postgres do
    table "rfqs"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :legal_entity, on_delete: :restrict
      reference :supplier, on_delete: :restrict
      reference :owner, on_delete: :nilify
    end

    custom_indexes do
      index [:organization_id, :supplier_id]
    end
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end
end
