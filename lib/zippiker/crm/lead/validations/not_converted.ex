defmodule Zippiker.Crm.Lead.Validations.NotConverted do
  @moduledoc "Converted leads are kept as history and can no longer change."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    if changeset.data.status == :converted,
      do: {:error, field: :status, message: "lead has already been converted"},
      else: :ok
  end
end
