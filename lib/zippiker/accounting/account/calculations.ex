defmodule Zippiker.Accounting.Account.Calculations do
  use Spark.Dsl.Fragment, of: Ash.Resource

  calculations do
    calculate :balance,
              :decimal,
              expr(
                if type in [:asset, :expense] do
                  debit_total - credit_total
                else
                  credit_total - debit_total
                end
              ) do
      description "All-time balance on the account's normal side."
      public? true
    end
  end
end
