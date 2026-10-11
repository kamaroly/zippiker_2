defimpl AshPhoenix.FormData.Error, for: Zippiker.Workflow.Errors.ChangeRequested do
  # A held change isn't a field problem; forms report it as a base error and
  # LiveViews turn it into a "sent for approval" flash (`change_requested/1`).
  def to_form_error(error), do: {:base, Exception.message(error), []}
end
