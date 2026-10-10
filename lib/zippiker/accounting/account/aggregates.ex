defmodule Zippiker.Accounting.Account.Aggregates do
  use Spark.Dsl.Fragment, of: Ash.Resource

  aggregates do
    sum :debit_total, :lines, :debit, public?: true, default: 0
    sum :credit_total, :lines, :credit, public?: true, default: 0
    exists :used?, :lines, public?: true
  end
end
