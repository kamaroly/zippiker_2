defmodule Zippiker.Accounting.Account.Relationships do
  use Spark.Dsl.Fragment, of: Ash.Resource

  relationships do
    has_many :lines, Zippiker.Accounting.JournalLine
  end
end
