defmodule Zippiker.Purchasing.BillLine.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    belongs_to :bill, Zippiker.Purchasing.Bill, allow_nil?: false, public?: true

    belongs_to :expense_account, Zippiker.Accounting.Account do
      public? true
      domain Zippiker.Accounting
    end
  end
end
