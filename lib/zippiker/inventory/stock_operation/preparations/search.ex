defmodule Zippiker.Inventory.StockOperation.Preparations.Search do
  @moduledoc "Filters operations by kind and by source document."
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    Enum.reduce([:kind, :source, :source_id], query, fn argument, query ->
      case Ash.Query.get_argument(query, argument) do
        nil -> query
        value -> Ash.Query.do_filter(query, [{argument, value}])
      end
    end)
  end
end
