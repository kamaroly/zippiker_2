defmodule Zippiker.HR.LeaveType.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 60]

    attribute :allowance_days, :decimal do
      description "Default working days per year, used when no leave policy applies; empty = no limit."
      public? true
      constraints min: 0
    end

    attribute :paid?, :boolean, allow_nil?: false, public?: true, default: true

    attribute :requires_approval?, :boolean do
      description "Off: requests are approved straight away."
      allow_nil? false
      public? true
      default true
    end

    attribute :color, :atom do
      allow_nil? false
      public? true
      default :blue
      constraints one_of: [:slate, :blue, :violet, :amber, :emerald, :rose, :orange, :teal]
    end

    attribute :active?, :boolean, allow_nil?: false, public?: true, default: true
    timestamps()
  end
end
