defmodule Zippiker.Platform.BillingInvoice.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Platform.BillingInvoice.Changes

  actions do
    defaults [:read]

    read :list do
      argument :organization_id, :uuid
      argument :status, :atom, constraints: [one_of: [:open, :paid, :void]]

      filter expr(
               (is_nil(^arg(:organization_id)) or organization_id == ^arg(:organization_id)) and
                 (is_nil(^arg(:status)) or status == ^arg(:status))
             )

      prepare build(sort: [issued_on: :desc, number: :desc], load: [:organization])
      pagination offset?: true, countable: true, default_limit: 25, required?: false
    end

    create :generate do
      description "Bills the workspace's current period, then moves its subscription forward."
      argument :organization_id, :uuid, allow_nil?: false
      change Changes.FromSubscription
      change Changes.AssignNumber
    end

    update :mark_paid do
      accept [:paid_on]
      validate attribute_equals(:status, :open), message: "only open invoices can be paid"
      change set_attribute(:status, :paid)
      change set_new_attribute(:paid_on, &Date.utc_today/0)
    end

    update :void do
      validate attribute_equals(:status, :open), message: "only open invoices can be voided"
      change set_attribute(:status, :void)
    end
  end
end
