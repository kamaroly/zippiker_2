defmodule Zippiker.Accounts.User.Calculations do
  use Spark.Dsl.Fragment, of: Ash.Resource

  calculations do
    calculate :display_name, :string, expr(name || type(email, :string)) do
      public? true
    end
  end
end
