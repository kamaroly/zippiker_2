defmodule Zippiker.Workflow.Callbacks do
  @moduledoc "Tells the document its approval finished (approved or rejected)."

  def finished(%{document_type: :expense_claim} = request, opts) do
    Zippiker.Expenses.apply_approval(request.document_id, request.status, opts)
  end

  def finished(%{document_type: :leave_request} = request, opts) do
    Zippiker.HR.apply_leave_approval(request.document_id, request.status, opts)
  end
end
