defmodule Zippiker.Workflow.ChangeRequest.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :number, :string, public?: true

    attribute :scope, :atom do
      allow_nil? false
      public? true

      constraints one_of: [
                    :employees,
                    :contacts,
                    :products,
                    :accounts,
                    :tax_rates,
                    :journal_entries
                  ]
    end

    attribute :resource, :string, allow_nil?: false, public?: true
    attribute :action, :atom, allow_nil?: false, public?: true

    attribute :action_type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:create, :update, :destroy]
    end

    attribute :record_id, :uuid, public?: true
    attribute :record_label, :string, public?: true, constraints: [max_length: 200]
    attribute :params, :map, allow_nil?: false, public?: true, default: %{}

    attribute :changes, {:array, :map} do
      description "Before/after per field: `%{field, from, to}`."
      allow_nil? false
      public? true
      default []
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :pending
      constraints one_of: [:pending, :applied, :rejected, :cancelled, :failed]
    end

    attribute :error, :string, public?: true, constraints: [max_length: 1_000]
    attribute :applied_at, :utc_datetime_usec, public?: true
    timestamps()
  end
end
