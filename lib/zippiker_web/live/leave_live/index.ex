defmodule ZippikerWeb.LeaveLive.Index do
  @moduledoc """
  Leave: your requests, requests waiting for your decision (as a manager or
  admin), everyone's, and who's away in the next 30 days. Requests are made
  in a modal that shows working days and the balance left.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.HR
  alias Zippiker.HR.{Entitlement, WorkingDays}

  @views ~w(mine approve all)

  @impl true
  def mount(_params, _session, socket) do
    opts = ash_opts(socket)

    me =
      case HR.my_employee_record(opts) do
        {:ok, employee} -> employee
        _ -> nil
      end

    today = Date.utc_today()

    {:ok,
     socket
     |> assign(page_title: "Leave", me: me)
     |> allow_upload(:attachment,
       accept: ~w(.pdf .jpg .jpeg .png .heic .doc .docx),
       max_entries: 1,
       max_file_size: 10_000_000
     )
     |> assign(:leave_types, HR.list_leave_types!(%{active_only?: true}, opts))
     |> assign(
       :away,
       HR.list_leave_requests!(
         %{status: :approved, from: today, to: Date.add(today, 30)},
         opts
       )
       |> Enum.sort_by(& &1.start_date, Date)
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    default = if socket.assigns.me, do: "mine", else: "approve"
    view = if params["view"] in @views, do: params["view"], else: default

    {:noreply,
     socket
     |> assign(:view, view)
     |> load_requests()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    employee_id =
      if can?(socket.assigns, "leave.request"),
        do: params["employee_id"] || (socket.assigns.me && socket.assigns.me.id),
        else: socket.assigns.me && socket.assigns.me.id

    form =
      HR.LeaveRequest
      |> AshPhoenix.Form.for_create(:create,
        as: "leave",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{
          "employee_id" => employee_id,
          "leave_type_id" => socket.assigns.leave_types |> List.first() |> then(&(&1 && &1.id))
        }
      )
      |> to_form()

    employees =
      if can?(socket.assigns, "leave.request"),
        do:
          Enum.map(
            HR.list_employees!(%{status: :active}, ash_opts(socket)),
            &{&1.name, &1.id}
          ),
        else: []

    socket
    |> assign(employee_options: employees)
    |> assign_form(form)
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil, policy: nil)

  @impl true
  def handle_event("validate", %{"leave" => params}, socket) do
    {:noreply, assign_form(socket, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"leave" => params}, socket) do
    organization_id = socket.assigns.current_organization.id

    params =
      case consume_uploaded_entries(socket, :attachment, fn %{path: path}, entry ->
             {:ok,
              {entry.client_name,
               ZippikerWeb.Uploads.store(path, organization_id, "leave", entry.client_name)}}
           end) do
        [{name, path}] ->
          Map.merge(params, %{"attachment_name" => name, "attachment_path" => path})

        [] ->
          params
      end

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, request} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           if(request.status == :approved,
             do: "Leave booked",
             else: "Request sent for approval"
           )
         )
         |> push_patch(to: ~p"/hr/leave?view=mine")}

      {:error, form} ->
        {:noreply, assign_form(socket, form)}
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket),
    do: {:noreply, cancel_upload(socket, :attachment, ref)}

  def handle_event("decide", %{"id" => id, "decision" => decision}, socket) do
    opts = ash_opts(socket)
    request = HR.get_leave_request!(id, opts)

    result =
      if decision == "approve",
        do: HR.approve_leave(request, opts),
        else: HR.reject_leave(request, opts)

    case result do
      {:ok, request} ->
        {:noreply,
         socket
         |> put_flash(:info, "Request #{request.status}")
         |> load_requests()}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("cancel", %{"id" => id}, socket) do
    opts = ash_opts(socket)

    case id |> HR.get_leave_request!(opts) |> HR.cancel_leave(opts) do
      {:ok, _request} ->
        {:noreply, socket |> put_flash(:info, "Request cancelled") |> load_requests()}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp load_requests(socket) do
    # Requests whose current workflow step the user approves.
    decidable =
      socket
      |> ash_opts()
      |> Zippiker.Workflow.approval_inbox!()
      |> Enum.filter(&(&1.document_type == :leave_request))
      |> MapSet.new(& &1.document_id)

    socket = assign(socket, :decidable, decidable)

    filters =
      case socket.assigns.view do
        "mine" -> %{mine?: true}
        "approve" -> %{status: :pending}
        "all" -> %{}
      end

    requests =
      filters
      |> HR.list_leave_requests!(ash_opts(socket) ++ [page: [limit: 50]])
      |> Map.fetch!(:results)
      |> then(fn requests ->
        if socket.assigns.view == "approve" and not can?(socket.assigns, "leave.approve"),
          do: Enum.filter(requests, &can_decide?(&1, socket.assigns)),
          else: requests
      end)

    stream(socket, :requests, requests, reset: true)
  end

  # Days and balance preview as the form changes.
  defp assign_form(socket, form) do
    form = to_form(form)
    params = AshPhoenix.Form.params(form)

    opts = ash_opts(socket)

    policy =
      with id when is_binary(id) and id != "" <- params["employee_id"],
           type_id when is_binary(type_id) and type_id != "" <- params["leave_type_id"] do
        Entitlement.policy_for(id, type_id, Keyword.put(opts, :authorize?, false))
      else
        _ -> nil
      end

    days =
      with {:ok, from} <- Date.from_iso8601(params["start_date"] || ""),
           {:ok, to} <- Date.from_iso8601(params["end_date"] || "") do
        if policy && policy.count_weekends_and_holidays?,
          do: WorkingDays.calendar_days(from, to),
          else: WorkingDays.count(from, to, WorkingDays.holidays(from, to, opts))
      else
        _ -> nil
      end

    balance =
      with id when is_binary(id) and id != "" <- params["employee_id"],
           type_id when is_binary(type_id) <- params["leave_type_id"] do
        id
        |> HR.leave_balances!(ash_opts(socket))
        |> Enum.find(&(&1.leave_type.id == type_id))
      else
        _ -> nil
      end

    assign(socket, form: form, days: days, balance: balance, policy: policy)
  end

  # Workflow requests: the user approves the current step. Older requests:
  # the employee's manager or an admin (never yourself).
  defp can_decide?(%{approval_request_id: id} = request, assigns) when is_binary(id),
    do: request.status == :pending and MapSet.member?(assigns.decidable, request.id)

  defp can_decide?(request, assigns) do
    request.status == :pending and request.employee.user_id != assigns.current_user.id and
      (can?(assigns, "leave.approve") or
         (request.employee.manager && request.employee.manager.user_id == assigns.current_user.id))
  end

  defp can_cancel?(request, assigns) do
    request.status in [:pending, :approved] and
      (can?(assigns, "leave.request") or request.employee.user_id == assigns.current_user.id)
  end

  defp upload_error(:too_large), do: "That file is over 10 MB"
  defp upload_error(:not_accepted), do: "Use a PDF, image or Word document"
  defp upload_error(:too_many_files), do: "Attach one file"
  defp upload_error(_error), do: "That file couldn't be uploaded"
end
