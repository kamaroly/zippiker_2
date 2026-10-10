defmodule Zippiker.Sales.Payment do
  @moduledoc "Money received against an issued invoice."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Sales,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPaperTrail.Resource],
    fragments: [
      Zippiker.Sales.Payment.Attributes,
      Zippiker.Sales.Payment.Relationships,
      Zippiker.Sales.Payment.Actions,
      Zippiker.Sales.Payment.Policies
    ]

  postgres do
    table "payments"
    repo Zippiker.Repo

    references do
      reference :organization, on_delete: :delete
      reference :invoice, on_delete: :restrict
      reference :recorded_by, on_delete: :nilify
    end

    custom_indexes do
      index [:organization_id, :paid_on]
    end
  end

  paper_trail do
    primary_key_type :uuid_v7
    # Drafts and payments can be hard-deleted; keep their history.
    reference_source? false
    store_action_name? true
    attributes_as_attributes [:organization_id]
    belongs_to_actor :user, Zippiker.Accounts.User, domain: Zippiker.Accounts
  end

  multitenancy do
    strategy :attribute
    attribute :organization_id
  end
end
