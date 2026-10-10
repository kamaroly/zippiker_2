defmodule Zippiker.HR.Employee.Calculations do
  use Spark.Dsl.Fragment, of: Ash.Resource

  calculations do
    calculate :name, :string, expr(party.name), public?: true
    calculate :email, :ci_string, expr(party.email), public?: true
    calculate :phone, :string, expr(party.phone), public?: true
  end
end
