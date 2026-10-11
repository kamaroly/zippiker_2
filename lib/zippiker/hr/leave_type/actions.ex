defmodule Zippiker.HR.LeaveType.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  @fields [:name, :description, :allowance_days, :paid?, :requires_approval?, :color, :active?]

  actions do
    defaults [:read]

    destroy :destroy do
      primary? true
      description "Only types never used in a request or claim (otherwise deactivate them)."
    end

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
