defmodule Zippiker.Accounts.Branch.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  alias Zippiker.Accounts.Branch

  @fields [
    :name,
    :code,
    :line1,
    :city,
    :country,
    :phone,
    :email,
    :manager_id,
    :default?,
    :active?
  ]

  actions do
    defaults [:read]

    read :list do
      argument :active_only?, :boolean, default: false
      filter expr(^arg(:active_only?) == false or active? == true)
      prepare build(sort: [default?: :desc, name: :asc], load: [:manager])
    end

    create :create do
      primary? true
      accept @fields
      change Branch.Changes.UpcaseCode
      change Branch.Changes.SingleDefault
    end

    update :update do
      primary? true
      require_atomic? false
      accept @fields
      change Branch.Changes.UpcaseCode
      change Branch.Changes.SingleDefault
    end

    destroy :destroy do
      primary? true
      description "Only branches never used on a record; otherwise deactivate them."
    end

    action :default, :struct do
      description "The default branch (Head office), created when missing."
      constraints instance_of: Branch
      run Branch.Actions.Default
    end
  end
end
