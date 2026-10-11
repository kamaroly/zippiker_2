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
      reference :pipeline, on_delete: :delete
      reference :stage, on_delete: :restrict
      reference :party, on_delete: :nilify
      reference :company, on_delete: :nilify
      reference :owner, on_delete: :nilify
    end

    custom_indexes do
      index [:stage_id, :position]
      index [:status, :closed_at]
      index [:party_id]
      index [:company_id]
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
    belongs_to_actor :user, Zippiker.Accounts.User, domain: Zippiker.Accounts
  end

  custom_fields do
    entity(:deal)
  end

  multitenancy do
    strategy :context
  end
end
