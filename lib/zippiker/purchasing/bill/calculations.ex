defmodule Zippiker.Purchasing.Bill.Calculations do
  use Spark.Dsl.Fragment, of: Ash.Resource

  calculations do
    # Same rule as invoices: total minus paid, zero once paid or void.
    calculate :amount_due, :money, Zippiker.Sales.Invoice.Calculations.AmountDue do
      public? true
    end

    calculate :overdue?,
              :boolean,
              expr(status == :open and not is_nil(due_on) and due_on < today()),
              public?: true
  end
end
