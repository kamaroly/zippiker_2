defmodule ZippikerWeb.DealLive.Board do
  @moduledoc "Kanban board of a pipeline. Drag cards between stages."
  use ZippikerWeb, :live_view

  alias Zippiker.Crm
  alias ZippikerWeb.DealLive.Column

  @impl true
  def mount(_params, _session, socket) do
    pipelines = Crm.list_pipelines!(ash_opts(socket))

    {:ok, assign(socket, pipelines: pipelines, page_title: "Deals"),
     temporary_assigns: [deals_by_stage: nil]}
  end

  @impl true
  def handle_params(params, _url, socket) do
    pipeline =
      Enum.find(socket.assigns.pipelines, &(&1.id == params["pipeline"])) ||
        List.first(socket.assigns.pipelines)

    socket =
      if socket.assigns[:pipeline] && socket.assigns.pipeline.id == pipeline.id do
        socket
      else
        load_board(socket, pipeline)
      end

    {:noreply, assign(socket, :new_stage_id, params["stage"])}
  end

  @impl true
  def handle_event("move", %{"id" => id, "stage_id" => stage_id, "position" => position}, socket) do
    opts = ash_opts(socket)
    deal = Crm.get_deal!(id, opts)
    from = deal.stage_id

    case Crm.move_deal(deal, stage_id, position / 1, opts) do
      {:ok, _deal} ->
        {:noreply, refresh_columns(socket, Enum.uniq([from, stage_id]))}

      {:error, _} ->
        {:noreply,
         socket |> put_flash(:error, "Could not move deal") |> refresh_columns([from, stage_id])}
    end
  end

  @impl true
  def handle_info({ZippikerWeb.DealLive.FormComponent, {:saved, deal}}, socket) do
    {:noreply,
     socket
     |> refresh_columns([deal.stage_id])
     |> put_flash(:info, "Deal created")
     |> push_patch(to: ~p"/deals")}
  end

  defp load_board(socket, pipeline) do
    opts = ash_opts(socket)
    stages = Ash.load!(pipeline.stages, [:deals_count, :deals_amount], opts)
    deals = Crm.board_deals!(pipeline.id, opts)

    socket
    |> assign(pipeline: pipeline, stages: stages)
    |> assign(:deals_by_stage, Enum.group_by(deals, & &1.stage_id))
    |> assign_totals()
  end

  # Reloads only the touched stages (totals + cards) and pushes them to their columns.
  defp refresh_columns(socket, stage_ids) do
    opts = ash_opts(socket)
    require Ash.Query

    deals =
      Crm.board_deals!(
        socket.assigns.pipeline.id,
        opts ++ [query: Ash.Query.filter(Crm.Deal, stage_id in ^stage_ids)]
      )
      |> Enum.group_by(& &1.stage_id)

    stages =
      Enum.map(socket.assigns.stages, fn stage ->
        if stage.id in stage_ids do
          stage = Ash.load!(stage, [:deals_count, :deals_amount], opts ++ [reuse_values?: false])

          send_update(Column,
            id: "stage-#{stage.id}",
            stage: stage,
            deals: Map.get(deals, stage.id, [])
          )

          stage
        else
          stage
        end
      end)

    socket |> assign(:stages, stages) |> assign_totals()
  end

  defp assign_totals(socket) do
    open = Enum.filter(socket.assigns.stages, &(&1.kind == :open))
    zero = Money.new!(socket.assigns.current_organization.currency, 0)

    assign(socket,
      open_value: Enum.reduce(open, zero, &Money.add!(&2, &1.deals_amount || zero)),
      open_count: Enum.sum_by(open, & &1.deals_count)
    )
  end

  defp first_open_stage_id(stages), do: Enum.find_value(stages, &(&1.kind == :open && &1.id))
end
