defmodule Zippiker.Sales.SalesOrder do
  @moduledoc """
  A confirmed sale to deliver (`SO-2026-0001`): draft → confirmed →
  delivered, or cancelled. Usually created from an accepted quote; delivering
  takes stock-tracked goods out of the warehouse; then it's invoiced.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Sales,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPaperTrail.Resource],
    fragments: [
      Zippiker.Sales.SalesOrder.Attributes,
      Zippiker.Sales.SalesOrder.Relationships,
      Zippiker.Sales.SalesOrder.Actions,
      Zippiker.Sales.SalesOrder.Policies
    ]

  postgres do
    table "sales_orders"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :legal_entity, on_delete: :restrict
      reference :customer, on_delete: :restrict
      reference :contact, on_delete: :nilify
      reference :deal, on_delete: :nilify
      reference :quote, on_delete: :nilify
      reference :warehouse, on_delete: :nilify
      reference :owner, on_delete: :nilify
    end

    custom_indexes do
      index [:organization_id, :status, :issued_on]
      index [:organization_id, :customer_id]
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
