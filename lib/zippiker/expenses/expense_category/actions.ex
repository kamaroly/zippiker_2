defmodule Zippiker.Expenses.ExpenseCategory.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  @fields [:name, :description, :account_id, :receipt_required?, :active?]

  actions do
    defaults [:read, :destroy]

    read :list do
      argument :active_only?, :boolean, default: false
      filter expr(^arg(:active_only?) == false or active? == true)
      prepare build(sort: [name: :asc], load: [:account])
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
