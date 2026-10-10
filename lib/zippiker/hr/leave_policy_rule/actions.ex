defmodule Zippiker.HR.LeavePolicyRule.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:leave_type_id, :days_per_year, :carry_over_days]
    end

    update :update do
      primary? true
      accept [:days_per_year, :carry_over_days]
    end
  end
end
