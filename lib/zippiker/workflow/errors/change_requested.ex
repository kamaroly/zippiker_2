defmodule Zippiker.Workflow.Errors.ChangeRequested do
  @moduledoc """
  Returned instead of applying a change when maker-checker is on: the
  change was saved as a change request for a checker to approve.
  """
  use Splode.Error, fields: [:number, :change_request_id], class: :invalid

  def message(%{number: number}),
    do: "Sent for approval as change request #{number}; it applies once a checker approves it"
end
