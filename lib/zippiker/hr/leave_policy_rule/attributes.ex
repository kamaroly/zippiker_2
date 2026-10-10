defmodule Zippiker.HR.LeavePolicyRule.Attributes do
  use Spark.Dsl.Fragment, of: Ash.Resource

  attributes do
    uuid_v7_primary_key :id

    attribute :days_per_year, :decimal do
      description "Working days per calendar year; empty means no limit."
      public? true
      constraints min: 0
    end

    attribute :carry_over_days, :decimal do
      description "Most unused days that roll into the next year."
      allow_nil? false
      public? true
      default 0
      constraints min: 0
    end
  end
end
