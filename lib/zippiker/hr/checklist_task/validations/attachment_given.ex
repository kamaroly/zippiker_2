defmodule Zippiker.HR.ChecklistTask.Validations.AttachmentGiven do
  @moduledoc "Tasks that need proof can only be marked done once a file is attached."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    task = changeset.data

    if task.requires_attachment? do
      %{attachments_count: count} =
        Ash.load!(task, [:attachments_count], tenant: changeset.tenant, authorize?: false)

      if count > 0, do: :ok, else: {:error, field: :note, message: "attach the document first"}
    else
      :ok
    end
  end
end
