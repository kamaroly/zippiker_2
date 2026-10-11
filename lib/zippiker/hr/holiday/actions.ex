defmodule Zippiker.HR.Holiday.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [
      :read,
      :destroy,
      create: [:name, :date, :recurring?],
      update: [:name, :date, :recurring?]
    ]

    read :list do
      prepare build(sort: [date: :asc])
    end
  end
end
