defmodule ZippikerWeb.ExpenseLive.Show do
  @moduledoc """
  An expense claim: its receipts, the approval timeline with approve/reject
  for whoever's turn it is, and the follow-ups (submit, pay back, cancel).
  """
  use ZippikerWeb, :live_view

  alias Zippiker.{Expenses, Workflow}
  alias Zippiker.Workflow.Approvers

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Expenses.get_expense_claim(id, ash_opts(socket)) do
      {:ok, _claim} ->
        {:ok, socket |> assign(:comment, "") |> load(id)}

      {:error, _} ->
        {:ok, socket |> put_flash(:error, "Claim not found") |> push_navigate(to: ~p"/expenses")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  defp load(socket, id) do
    opts = ash_opts(socket)

    claim =
      Expenses.get_expense_claim!(
        id,
        opts ++ [load: [:claimant, :legal_entity, employee: [:name], items: [:category]]]
      )

    request =
      claim.approval_request_id &&
        Workflow.get_approval_request!(
          claim.approval_request_id,
          opts ++ [load: [:requested_by, steps: [:user, :group, :decided_by]]]
        )

    assign(socket,
      claim: claim,
      request: request,
      page_title: claim.number,
      can_decide?: can_decide?(request, socket),
      owner?: claim.claimant_id == socket.assigns.current_user.id
    )
  end

  defp can_decide?(%{status: :pending} = request, socket) do
    case Enum.find(request.steps, &(&1.status == :pending)) do
      nil ->
        false

      step ->
        socket.assigns.current_user.id in Approvers.for_step(
          step,
          request,
          socket.assigns.current_organization
        )
    end
  end

  defp can_decide?(_request, _socket), do: false

  @impl true
  def handle_event("decide", %{"decision" => decision} = params, socket)
      when decision in ["approve", "reject"] do
    decision = String.to_existing_atom(decision)
    comment = params |> Map.get("comment", "") |> String.trim()

    if decision == :reject and comment == "" do
      {:noreply, put_flash(socket, :error, "Say why you're rejecting it")}
    else
      case Workflow.decide_approval(
             socket.assigns.request,
             decision,
             %{comment: if(comment == "", do: nil, else: comment)},
             ash_opts(socket)
           ) do
        {:ok, _request} ->
          {:noreply,
           socket
           |> put_flash(:info, if(decision == :approve, do: "Approved", else: "Rejected"))
           |> assign(:comment, "")
           |> load(socket.assigns.claim.id)}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, error_message(error))}
      end
    end
  end

  def handle_event("submit", _params, socket) do
    socket.assigns.claim
    |> Expenses.submit_expense_claim(ash_opts(socket))
    |> respond(socket, "Claim submitted for approval")
  end

  def handle_event("cancel", _params, socket) do
    socket.assigns.claim
    |> Expenses.cancel_expense_claim(ash_opts(socket))
    |> respond(socket, "Claim cancelled")
  end

  def handle_event("delete", _params, socket) do
    case Expenses.delete_expense_claim(socket.assigns.claim, ash_opts(socket)) do
      :ok ->
        {:noreply,
         socket |> put_flash(:info, "Draft deleted") |> push_navigate(to: ~p"/expenses")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("reimburse", %{"reimburse" => params}, socket) do
    socket.assigns.claim
    |> Expenses.reimburse_expense_claim(params, ash_opts(socket))
    |> case do
      {:ok, claim} ->
        {:noreply,
         socket
         |> put_flash(:info, "Marked as paid back")
         |> load(claim.id)
         |> push_patch(to: ~p"/expenses/#{claim}")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp respond({:ok, claim}, socket, message) do
    message = if claim.status == :approved, do: "Claim approved", else: message
    {:noreply, socket |> put_flash(:info, message) |> load(claim.id)}
  end

  defp respond({:error, error}, socket, _message),
    do: {:noreply, put_flash(socket, :error, error_message(error))}
end
