defmodule ZippikerWeb.MeLive.Overview do
  @moduledoc """
  Employee self-service: your leave balances and upcoming time off, open
  requests and claims, the onboarding/offboarding tasks assigned to you,
  and shortcuts to request leave, claim expenses or claim leave.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.{Expenses, HR}

  @impl true
  def mount(_params, _session, socket) do
    opts = ash_opts(socket)

    me =
      case HR.my_employee_record(opts) do
        {:ok, employee} -> Ash.load!(employee, [:name, :department, manager: [:name]], opts)
        _ -> nil
      end

    socket = assign(socket, page_title: "My workspace", me: me)

    {:ok,
     if me do
       today = Date.utc_today()
       requests = HR.list_leave_requests!(%{mine?: true}, opts ++ [page: [limit: 50]]).results

       assign(socket,
         balances: HR.leave_balances!(me.id, opts),
         upcoming:
           requests
           |> Enum.filter(
             &(&1.status in [:pending, :approved] and Date.compare(&1.end_date, today) != :lt)
           )
           |> Enum.sort_by(& &1.start_date, Date),
         claims:
           if(module?(socket.assigns, :expenses),
             do:
               Expenses.list_expense_claims!(%{mine?: true}, opts ++ [page: [limit: 5]]).results,
             else: []
           ),
         tasks: HR.my_checklist_tasks!(opts),
         approvals: length(Zippiker.Workflow.approval_inbox!(opts))
       )
     else
       socket
     end}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}
end
