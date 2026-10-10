defmodule ZippikerWeb.DashboardLive do
  @moduledoc "Overview: pipeline health, revenue trend and today's agenda."
  use ZippikerWeb, :live_view

  alias Zippiker.Crm

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Dashboard", now: DateTime.utc_now())
     |> assign(
       :summary,
       if(module?(socket.assigns, :crm), do: Crm.dashboard_summary!(ash_opts(socket)))
     )
     |> assign(
       :sales,
       if(module?(socket.assigns, :sales), do: Zippiker.Sales.sales_summary!(ash_opts(socket)))
     )}
  end

  # Shown instead of the pipeline when the CRM module is off.
  defp quick_links(assigns) do
    [
      {"Contacts", "hero-users", ~p"/contacts", nil},
      {"Companies", "hero-building-office-2", ~p"/companies", nil},
      {"Invoices", "hero-banknotes", ~p"/invoices", :sales},
      {"Quotes", "hero-document-text", ~p"/quotes", :sales},
      {"Accounting", "hero-calculator", ~p"/accounting", :accounting},
      {"Help center", "hero-question-mark-circle", ~p"/help", nil}
    ]
    |> Enum.filter(fn {_label, _icon, _path, module} ->
      is_nil(module) or module?(assigns, module)
    end)
    |> Enum.map(fn {label, icon, path, _module} -> {label, icon, path} end)
  end
end
