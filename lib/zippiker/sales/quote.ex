defmodule Zippiker.Sales.Quote do
  @moduledoc """
  A price proposal to a customer. Numbered on creation (`QUO-2026-0001`),
  moves draft → sent → accepted / declined, and can be turned into an invoice.
  Accepting a quote linked to a deal marks the deal as won.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Sales,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [
      AshArchival.Resource,
      AshPaperTrail.Resource,
      Zippiker.Extensibility.CustomFields
    ],
    fragments: [
      Zippiker.Sales.Quote.Attributes,
      Zippiker.Sales.Quote.Relationships,
      Zippiker.Sales.Quote.Actions,
      Zippiker.Sales.Quote.Policies
    ]

  postgres do
    table "quotes"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :legal_entity, on_delete: :restrict
      reference :customer, on_delete: :restrict
      reference :contact, on_delete: :nilify
      reference :deal, on_delete: :nilify
      reference :owner, on_delete: :nilify
    end

    custom_indexes do
      index [:organization_id, :status, :issued_on]
      index [:organization_id, :customer_id]
      index [:organization_id, :deal_id]
    end
  end

  archive do
    base_filter? true
  end

  paper_trail do
    primary_key_type :uuid_v7
    change_tracking_mode :changes_only
    store_action_name? true
    ignore_attributes [:inserted_at, :updated_at]
    attributes_as_attributes [:organization_id]
    belongs_to_actor :user, Zippiker.Accounts.User, domain: Zippiker.Accounts
  end

  custom_fields do
    entity(:quote)
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end
end
