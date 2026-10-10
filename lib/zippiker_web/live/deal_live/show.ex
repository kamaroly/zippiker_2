defmodule ZippikerWeb.DealLive.Show do
  @moduledoc "A deal: stage progress, details, timeline and tasks."
  use ZippikerWeb, :live_view

  alias Zippiker.{Crm, Extensibility}

  @loads [:stage, :party, :company, :owner, :lead, :probability, :overdue?]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    opts = ash_opts(socket)

    case Crm.get_deal(id, opts ++ [load: @loads]) do
      {:ok, deal} ->
        pipeline = Crm.get_pipeline!(deal.pipeline_id, opts ++ [load: [:stages]])

        {:ok,
         socket
         |> assign(deal: deal, pipeline: pipeline, page_title: deal.title)
         |> assign(:definitions, Extensibility.list_custom_fields!(:deal, opts))
         |> assign(:quotes, Zippiker.Sales.list_quotes!(%{deal_id: deal.id}, opts))
         |> assign(:invoices, Zippiker.Sales.list_invoices!(%{deal_id: deal.id}, opts))}

      {:error, _} ->
        {:ok, socket |> put_flash(:error, "Deal not found") |> push_navigate(to: ~p"/deals")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("move", %{"stage" => stage_id}, socket) do
    opts = ash_opts(socket)
    deal = Crm.move_deal!(socket.assigns.deal, stage_id, socket.assigns.deal.position, opts)
    {:noreply, assign(socket, :deal, Ash.load!(deal, @loads, opts))}
  end

  def handle_event("archive", _params, socket) do
    Crm.archive_deal!(socket.assigns.deal, ash_opts(socket))
    {:noreply, socket |> put_flash(:info, "Deal archived") |> push_navigate(to: ~p"/deals")}
  end

  @impl true
  def handle_info({ZippikerWeb.DealLive.FormComponent, {:saved, deal}}, socket) do
    opts = ash_opts(socket)
    deal = Ash.load!(deal, @loads, opts)
    pipeline = Crm.get_pipeline!(deal.pipeline_id, opts ++ [load: [:stages]])

    {:noreply,
     socket
     |> assign(deal: deal, pipeline: pipeline, page_title: deal.title)
     |> put_flash(:info, "Saved")
     |> push_patch(to: ~p"/deals/#{deal}")}
  end

  # Open stages before the current one are "done" while the deal is open or won.
  defp reached?(%{kind: :open} = stage, %{status: status} = deal, _pipeline) when status != :lost,
    do: stage.position < deal.stage.position

  defp reached?(_stage, _deal, _pipeline), do: false
end
