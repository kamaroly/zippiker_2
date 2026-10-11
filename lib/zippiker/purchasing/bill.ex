defmodule Zippiker.Purchasing.Bill do
  @moduledoc """
  A supplier's invoice to us (`BILL-2026-0001`, with the supplier's own
  reference). Drafts are edited freely; approving posts it to the books (and
  brings stock in when it wasn't ordered on a PO); payments move it to paid.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Purchasing,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPaperTrail.Resource],
    fragments: [
      Zippiker.Purchasing.Bill.Attributes,
      Zippiker.Purchasing.Bill.Relationships,
      Zippiker.Purchasing.Bill.Aggregates,
      Zippiker.Purchasing.Bill.Calculations,
      Zippiker.Purchasing.Bill.Actions,
      Zippiker.Purchasing.Bill.Policies
    ]

  postgres do
    table "bills"
    repo Zippiker.Repo

    references do
      reference :branch, on_delete: :restrict
      reference :legal_entity, on_delete: :restrict
      reference :supplier, on_delete: :restrict
      reference :purchase_order, on_delete: :nilify
      reference :owner, on_delete: :nilify
    end

    custom_indexes do
      index [:status, :due_on]
      index [:supplier_id]
    end
  end

  paper_trail do
    primary_key_type :uuid_v7
    change_tracking_mode :changes_only
    store_action_name? true
    reference_source? false
    ignore_attributes [:inserted_at, :updated_at]
    belongs_to_actor :user, Zippiker.Accounts.User, domain: Zippiker.Accounts
  end

  multitenancy do
    strategy :context
  end
end
