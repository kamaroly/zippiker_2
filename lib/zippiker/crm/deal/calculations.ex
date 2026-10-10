defmodule Zippiker.Crm.Deal.Calculations do
  use Spark.Dsl.Fragment, of: Ash.Resource

  calculations do
    calculate :probability, :integer, expr(stage.probability), public?: true

    calculate :overdue?,
              :boolean,
              expr(
                status == :open and not is_nil(expected_close_on) and expected_close_on < today()
              ),
              public?: true
  end
end
