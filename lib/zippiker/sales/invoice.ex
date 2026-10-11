defmodule Zippiker.Sales.Invoice do
  @moduledoc """
  A bill to a customer. Drafts have no number; issuing allocates the next
  gap-free number (`INV-2026-0001`) and sets the due date from the legal
  entity's payment terms. Payments move it to paid; issued invoices without
  payments can be voided.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Sales,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPaperTrail.Resource, Zippiker.Extensibility.CustomFields],
    fragments: [
      Zippiker.Sales.Invoice.Attributes,
      Zippiker.Sales.Invoice.Relationships,
      Zippiker.Sales.Invoice.Aggregates,
      Zippiker.Sales.Invoice.Calculations,
      Zippiker.Sales.Invoice.Actions,
      Zippiker.Sales.Invoice.Policies
    ]

  postgres do
    table "invoices"
    repo Zippiker.Repo

    identity_wheres_to_sql unique_number: "number IS NOT NULL"

    references do
      reference :branch, on_delete: :restrict
      reference :legal_entity, on_delete: :restrict
      reference :customer, on_delete: :restrict
      reference :contact, on_delete: :nilify
      reference :deal, on_delete: :nilify
      reference :quote, on_delete: :nilify
      reference :sales_order, on_delete: :nilify
      reference :owner, on_delete: :nilify
    end

    custom_indexes do
      index [:status, :due_on]
      index [:issued_on]
      index [:customer_id]
    end
  end

  paper_trail do
    primary_key_type :uuid_v7
    # Drafts and payments can be hard-deleted; keep their history.
    reference_source? false
    change_tracking_mode :changes_only
    store_action_name? true
    ignore_attributes [:inserted_at, :updated_at]
    belongs_to_actor :user, Zippiker.Accounts.User, domain: Zippiker.Accounts
  end

  custom_fields do
    entity(:invoice)
  end

  multitenancy do
    strategy :context
  end

  identities do
    identity :unique_number, [:legal_entity_id, :number], where: expr(not is_nil(number))
  end
end
