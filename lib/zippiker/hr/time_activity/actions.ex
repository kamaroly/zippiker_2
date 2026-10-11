defmodule Zippiker.HR.TimeActivity.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.HR.LeaveRequest.Changes, as: RequestChanges
  alias Zippiker.HR.TimeActivity.Preparations

  @fields [
    :employee_id,
    :date,
    :hours,
    :pay_type,
    :billable?,
    :hourly_rate,
    :description,
    :customer_id,
    :deal_id,
    :product_id
  ]

  actions do
    defaults [:read, :destroy]

    read :search do
      argument :employee_id, :uuid
      argument :mine?, :boolean, default: false
      argument :from, :date
      argument :to, :date
      prepare Preparations.Search

      prepare build(
                sort: [date: :desc, inserted_at: :desc],
                load: [:customer, :deal, employee: [:name]]
              )

      pagination offset?: true, countable: true, default_limit: 100, required?: false
    end

    create :create do
      primary? true
      accept @fields
      change RequestChanges.DefaultEmployee
    end

    update :update do
      primary? true
      accept @fields -- [:employee_id]
    end

    update :mark_billed do
      description "Links the time to the invoice it was billed on."
      accept [:invoice_id]
    end
  end
end
