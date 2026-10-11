defmodule ZippikerWeb.Platform.TeamsLive do
  @moduledoc "Every workspace with plan, status and size; searchable."
  use ZippikerWeb, :live_view

  alias Zippiker.{Accounts, Platform}

  @statuses ~w(trialing active past_due canceled)
  @currencies ~w(USD EUR GBP CAD AUD RWF KES UGX TZS NGN ZAR GHS XOF INR JPY CHF)

  @impl true
  def mount(_params, _session, socket),
    do: {:ok, assign(socket, page_title: "Workspaces", currencies: @currencies, form: nil)}

  @impl true
  def handle_params(params, _url, socket) do
    actor = [actor: socket.assigns.current_user]
    query = params["q"] || ""
    status = if params["status"] in @statuses, do: String.to_existing_atom(params["status"])

    {teams, page} =
      if status do
        # Filtering by subscription status starts from subscriptions.
        subscriptions = Platform.list_subscriptions!(%{status: status}, actor)

        teams =
          Enum.map(subscriptions, &Ash.Resource.put_metadata(&1.organization, :subscription, &1))

        {Enum.filter(teams, &matches?(&1, query)), nil}
      else
        page =
          Accounts.platform_organizations!(
            %{query: query},
            actor ++ [page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]]
          )

        {with_subscriptions(page.results, actor), page}
      end

    {:noreply,
     socket
     |> assign(query: query, status: status, page: page)
     |> assign(:form, if(socket.assigns.live_action == :new, do: new_form(socket)))
     |> stream(:teams, teams, reset: true)}
  end

  defp new_form(socket) do
    Accounts.Organization
    |> AshPhoenix.Form.for_create(:platform_create,
      as: "workspace",
      actor: socket.assigns.current_user,
      params: %{"currency" => "USD"}
    )
    |> to_form()
  end

  @impl true
  def handle_event("validate", %{"workspace" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("create", %{"workspace" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, organization} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{organization.name} created for #{params["owner_email"]}")
         |> push_navigate(to: ~p"/platform/teams/#{organization}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: teams_path(%{q: query, status: socket.assigns.status}))}
  end

  defp with_subscriptions(teams, actor) do
    by_org =
      %{organization_ids: Enum.map(teams, & &1.id)}
      |> Platform.list_subscriptions!(actor)
      |> Map.new(&{&1.organization_id, &1})

    Enum.map(teams, &Ash.Resource.put_metadata(&1, :subscription, by_org[&1.id]))
  end

  defp subscription(team), do: team.__metadata__[:subscription]

  defp matches?(_team, ""), do: true

  defp matches?(team, query),
    do: String.contains?(String.downcase(team.name), String.downcase(query))

  defp teams_path(params), do: query_path(~p"/platform/teams", params)
end
