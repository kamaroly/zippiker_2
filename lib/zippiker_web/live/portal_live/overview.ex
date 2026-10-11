defmodule ZippikerWeb.PortalLive.Overview do
  @moduledoc """
  A portal's home: for customers their quotes, orders, invoices and what
  they owe; for suppliers their requests for quotation, purchase orders
  and bills.
  """
  use ZippikerWeb, :live_view

  alias Zippiker.Portal

  @impl true
  def mount(%{"access_id" => access_id}, _session, socket) do
    case Portal.portal_overview(access_id, actor: socket.assigns.current_user) do
      {:ok, overview} ->
        {:ok,
         assign(socket,
           page_title: overview.organization.name,
           overview: overview,
           access: overview.access
         )}

      {:error, _} ->
        {:ok, socket |> put_flash(:error, "Portal not found") |> push_navigate(to: ~p"/portal")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  defp doc_path(access, type, document), do: ~p"/portal/#{access.id}/#{type}/#{document.id}"
end
