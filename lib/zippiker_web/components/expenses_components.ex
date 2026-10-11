defmodule ZippikerWeb.ExpensesComponents do
  @moduledoc "Expense claim badges."
  use Phoenix.Component

  import ZippikerWeb.CoreComponents

  alias ZippikerWeb.Format

  attr :status, :atom, required: true

  def claim_status(assigns) do
    ~H"""
    <.badge color={
      %{
        draft: :slate,
        submitted: :amber,
        approved: :blue,
        rejected: :rose,
        reimbursed: :emerald,
        cancelled: :slate
      }[@status]
    }>
      {claim_status_label(@status)}
    </.badge>
    """
  end

  def claim_status_label(:submitted), do: "Awaiting approval"
  def claim_status_label(:reimbursed), do: "Paid back"
  def claim_status_label(status), do: Format.humanize(status)
end
