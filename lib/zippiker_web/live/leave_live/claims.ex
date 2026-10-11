defmodule ZippikerWeb.LeaveLive.Claims do
  @moduledoc """
  Leave claims: people ask for days to be added to their balance (e.g. time
  off in lieu of overtime) on leave types whose policy allows claims; their
  manager or an admin approves.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.HR
  alias Zippiker.HR.Entitlement

  @views ~w(mine approve all)

  @impl true
  def mount(_params, _session, socket) do
    me =
      case HR.my_employee_record(ash_opts(socket)) do
        {:ok, employee} -> employee
        _ -> nil
      end

    {:ok, assign(socket, page_title: "Leave claims", me: me)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    default = if socket.assigns.me, do: "mine", else: "approve"
    view = if params["view"] in @views, do: params["view"], else: default

    {:noreply,
     socket
     |> assign(:view, view)
     |> load()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    employee_id =
      if admin?(socket.assigns),
        do: params["employee_id"] || (socket.assigns.me && socket.assigns.me.id),
        else: socket.assigns.me && socket.assigns.me.id

    employees =
      if admin?(socket.assigns),
        do: Enum.map(HR.list_employees!(%{status: :active}, ash_opts(socket)), &{&1.name, &1.id}),
        else: []

    socket
    |> assign(employee_options: employees)
    |> assign_form(%{
      "employee_id" => employee_id,
      "worked_on" => Date.to_iso8601(Date.utc_today())
    })
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil)

  defp assign_form(socket, params) do
    types = claimable_types(params["employee_id"], socket)

    params =
      if params["leave_type_id"] in Enum.map(types, &elem(&1, 1)),
        do: params,
        else: Map.put(params, "leave_type_id", types |> List.first({nil, nil}) |> elem(1))

    form =
      HR.LeaveClaim
      |> AshPhoenix.Form.for_create(:create,
        as: "claim",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: params
      )
      |> to_form()

    assign(socket, form: form, claimable_types: types)
  end

  # Leave types whose policy for this employee allows claims.
  defp claimable_types(employee_id, socket) when is_binary(employee_id) and employee_id != "" do
    opts = ash_opts(socket)

    for type <- HR.list_leave_types!(%{active_only?: true}, opts),
        match?(
          %{claimable?: true},
          Entitlement.policy_for(employee_id, type.id, Keyword.put(opts, :authorize?, false))
        ),
        do: {type.name, type.id}
  end

  defp claimable_types(_employee_id, _socket), do: []

  @impl true
  def handle_event("validate", %{"claim" => params}, socket) do
    socket = assign_form(socket, params)

    {:noreply,
     assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params) |> to_form())}
  end

  def handle_event("save", %{"claim" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _claim} ->
        {:noreply,
         socket
         |> put_flash(:info, "Claim sent for approval")
         |> push_patch(to: ~p"/hr/leave-claims?view=mine")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("decide", %{"id" => id, "decision" => decision}, socket) do
    opts = ash_opts(socket)
    claim = HR.get_leave_claim!(id, opts)

    result =
      if decision == "approve",
        do: HR.approve_leave_claim(claim, opts),
        else: HR.reject_leave_claim(claim, opts)

    case result do
      {:ok, claim} -> {:noreply, socket |> put_flash(:info, "Claim #{claim.status}") |> load()}
      {:error, error} -> {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("cancel", %{"id" => id}, socket) do
    opts = ash_opts(socket)

    case id |> HR.get_leave_claim!(opts) |> HR.cancel_leave_claim(opts) do
      {:ok, _claim} -> {:noreply, socket |> put_flash(:info, "Claim withdrawn") |> load()}
      {:error, error} -> {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp load(socket) do
    filters =
      case socket.assigns.view do
        "mine" -> %{mine?: true}
        "approve" -> if admin?(socket.assigns), do: %{status: :pending}, else: %{to_decide?: true}
        "all" -> %{}
      end

    claims = HR.list_leave_claims!(filters, ash_opts(socket) ++ [page: [limit: 50]]).results
    stream(socket, :claims, claims, reset: true)
  end

  defp can_decide?(claim, assigns) do
    claim.status == :pending and claim.employee.user_id != assigns.current_user.id and
      (admin?(assigns) or
         (claim.employee.manager && claim.employee.manager.user_id == assigns.current_user.id))
  end

  defp can_cancel?(claim, assigns) do
    claim.status == :pending and
      (admin?(assigns) or claim.employee.user_id == assigns.current_user.id)
  end
end
