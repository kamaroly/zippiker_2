defmodule Zippiker.Expenses.ExpenseItem.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  @fields [:position, :spent_on, :description, :merchant, :amount, :category_id]

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:claim_id | @fields]
    end

    update :update do
      primary? true
      accept @fields
    end
  end
end
