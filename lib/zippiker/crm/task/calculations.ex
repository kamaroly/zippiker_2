defmodule Zippiker.Crm.Task.Calculations do
  use Spark.Dsl.Fragment, of: Ash.Resource

  calculations do
    calculate :done?, :boolean, expr(not is_nil(completed_at)), public?: true

    calculate :overdue?,
              :boolean,
              expr(is_nil(completed_at) and not is_nil(due_on) and due_on < today()),
              public?: true
  end
end
