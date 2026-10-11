defmodule Zippiker.Compliance.Resolution.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [
      :read,
      :destroy,
      create: [:meeting_id, :position, :text, :kind, :passed?],
      update: [:position, :text, :kind, :passed?]
    ]
  end
end
