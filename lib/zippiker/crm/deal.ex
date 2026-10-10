defmodule Zippiker.Crm.Deal do
  @moduledoc "A sales opportunity with a contact and/or company, moving through a pipeline."
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
      Zippiker.Crm.Deal.Attributes,
      Zippiker.Crm.Deal.Relationships,
      Zippiker.Crm.Deal.Calculations,
      Zippiker.Crm.Deal.Actions,
      Zippiker.Crm.Deal.Policies
    ]

  postgres do
    table "deals"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :pipeline, on_delete: :delete
      reference :stage, on_delete: :restrict
      reference :party, on_delete: :nilify
      reference :company, on_delete: :nilify
      reference :owner, on_delete: :nilify
    end

    custom_indexes do
      index [:organization_id, :stage_id, :position]
      index [:organization_id, :status, :closed_at]
      index [:organization_id, :party_id]
      index [:organization_id, :company_id]
    end
  end

  archive do
    base_filter? true
  end

  paper_trail do
    primary_key_type :uuid_v7
    change_tracking_mode :changes_only
    store_action_name? true
    ignore_attributes [:inserted_at, :updated_at, :position]
    attributes_as_attributes [:organization_id]
    belongs_to_actor :user, Zippiker.Accounts.User, domain: Zippiker.Accounts
  end

  custom_fields do
    entity(:deal)
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end
end
