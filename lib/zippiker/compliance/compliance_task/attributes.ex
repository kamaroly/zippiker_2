defmodule Zippiker.Compliance.ComplianceTask.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :kind, :atom do
      allow_nil? false
      public? true
      default :other

      constraints one_of: [
                    :annual_return,
                    :officer_change,
                    :office_change,
                    :allotment_return,
                    :beneficial_ownership,
                    :charge_registration,
                    :charge_satisfaction,
                    :resolution_filing,
                    :agm,
                    :other
                  ]
    end

    attribute :title, :string, allow_nil?: false, public?: true, constraints: [max_length: 200]
    attribute :description, :string, public?: true, constraints: [max_length: 1_000]
    attribute :due_on, :date, allow_nil?: false, public?: true
    attribute :completed_on, :date, public?: true

    attribute :reference, :string do
      description "Filing receipt / e-Citizen reference."
      public? true
      constraints max_length: 80
    end

    attribute :notes, :string, public?: true, constraints: [max_length: 1_000]
    attribute :period, :string, public?: true, constraints: [max_length: 40]
    timestamps()
  end

  calculations do
    calculate :state,
              :atom,
              expr(
                cond do
                  not is_nil(completed_on) -> :done
                  due_on < today() -> :overdue
                  due_on <= date_add(today(), 14, :day) -> :due_soon
                  true -> :upcoming
                end
              ),
              public?: true
  end
end
