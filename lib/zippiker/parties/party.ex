defmodule Zippiker.Parties.Party do
  @moduledoc """
  A person or an organization. `roles` records how the business relates to
  them (lead, customer, supplier, ...), so one record can play many roles.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Parties,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [
      AshArchival.Resource,
      AshPaperTrail.Resource,
      Zippiker.Extensibility.CustomFields
    ],
    fragments: [
      Zippiker.Parties.Party.Attributes,
      Zippiker.Parties.Party.Relationships,
      Zippiker.Parties.Party.Actions,
      Zippiker.Parties.Party.Policies
    ]

  postgres do
    table "parties"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :employer, on_delete: :nilify
      reference :owner, on_delete: :nilify
    end

    custom_indexes do
      index [:organization_id, :kind, :name]
      index [:organization_id, :employer_id]
    end
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
    entity_from(:kind)
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end
end
