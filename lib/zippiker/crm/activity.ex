defmodule Zippiker.Crm.Activity do
  @moduledoc "A note, call, email or meeting logged against a contact, company, lead or deal."
  use Ash.Resource,
    otp_app: :zippiker,
    domain: Zippiker.Crm,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    fragments: [
      Zippiker.Crm.Activity.Attributes,
      Zippiker.Crm.Activity.Relationships,
      Zippiker.Crm.Activity.Actions,
      Zippiker.Crm.Activity.Policies
    ]

  postgres do
    table "activities"
    repo Zippiker.Repo

    references do
      reference :party, on_delete: :delete
      reference :deal, on_delete: :delete
      reference :lead, on_delete: :delete
      reference :author, on_delete: :nilify
    end

    custom_indexes do
      index [:occurred_at]
      index [:party_id]
      index [:deal_id]
      index [:lead_id]
    end
  end

  multitenancy do
    strategy :context
  end
end
