defmodule Zippiker.Purchasing.PurchaseOrder do
  @moduledoc """
  An order to a supplier (`PO-2026-0001`): draft → ordered → (partially)
  received, or cancelled. Receiving brings stock-tracked lines into a
  warehouse; a bill can then be created from it.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Purchasing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPaperTrail.Resource],
    fragments: [
      Zippiker.Purchasing.PurchaseOrder.Attributes,
      Zippiker.Purchasing.PurchaseOrder.Relationships,
      Zippiker.Purchasing.PurchaseOrder.Actions,
      Zippiker.Purchasing.PurchaseOrder.Policies
    ]

  postgres do
    table "purchase_orders"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :legal_entity, on_delete: :restrict
      reference :supplier, on_delete: :restrict
      reference :warehouse, on_delete: :nilify
      reference :rfq, on_delete: :nilify
      reference :owner, on_delete: :nilify
    end

    custom_indexes do
      index [:organization_id, :status, :issued_on]
      index [:organization_id, :supplier_id]
    end
  end

  paper_trail do
    primary_key_type :uuid_v7
    change_tracking_mode :changes_only
    store_action_name? true
    reference_source? false
    ignore_attributes [:inserted_at, :updated_at]
    attributes_as_attributes [:organization_id]
    belongs_to_actor :user, Zippiker.Accounts.User, domain: Zippiker.Accounts
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end
end
