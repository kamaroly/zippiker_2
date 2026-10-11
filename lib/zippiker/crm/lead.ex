defmodule Zippiker.Crm.Lead do
  @moduledoc """
  An unqualified prospect. Converting a lead creates (or reuses) a company and
  a contact in `Zippiker.Parties`, and optionally a deal.
  """
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Crm,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [
      AshArchival.Resource,
      AshPaperTrail.Resource,
      Zippiker.Extensibility.CustomFields
    ],
    fragments: [
      Zippiker.Crm.Lead.Attributes,
      Zippiker.Crm.Lead.Relationships,
      Zippiker.Crm.Lead.Actions,
      Zippiker.Crm.Lead.Policies
    ]

  postgres do
    table "leads"
    repo Zippiker.Repo

    references do
      reference :owner, on_delete: :nilify
      reference :party, on_delete: :nilify
      reference :company, on_delete: :nilify
    end

    custom_indexes do
      index [:status, :inserted_at]
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
    belongs_to_actor :user, Zippiker.Accounts.User, domain: Zippiker.Accounts
  end

  custom_fields do
    entity(:lead)
  end

  multitenancy do
    strategy :context
  end
end
