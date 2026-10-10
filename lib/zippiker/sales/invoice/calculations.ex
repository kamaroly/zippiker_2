defmodule Zippiker.Sales.Invoice.Calculations do
  use Spark.Dsl.Fragment, of: Ash.Resource

  calculations do
    calculate :amount_due, :money, Zippiker.Sales.Invoice.Calculations.AmountDue do
      public? true
    end

    calculate :overdue?,
              :boolean,
              expr(status == :issued and not is_nil(due_on) and due_on < today()),
              public?: true
  end
end
