defmodule Zippiker.HR.LeaveType.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  @fields [:name, :allowance_days, :paid?, :requires_approval?, :color, :active?]

  actions do
    defaults [:read]

    read :list do
      argument :active_only?, :boolean, default: false
      filter expr(^arg(:active_only?) == false or active? == true)
      prepare build(sort: [name: :asc])
    end

    create :create do
      primary? true
      accept @fields
    end

    update :update do
      primary? true
      accept @fields
    end
  end
end
