defmodule Zippiker.Sales.Validations.InStatus do
  @moduledoc "The document's current status must be one of `statuses`."
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, opts, _context) do
    statuses = Keyword.fetch!(opts, :statuses)

    if changeset.data.status in statuses,
      do: :ok,
      else:
        {:error,
         field: :status,
         message: Keyword.get(opts, :message, "not allowed while #{changeset.data.status}")}
  end
end
