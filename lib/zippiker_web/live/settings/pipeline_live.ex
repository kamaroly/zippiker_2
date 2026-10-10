defmodule ZippikerWeb.Settings.PipelineLive do
  @moduledoc "Rename stages, tune win probabilities and colors, add or remove stages."
  use ZippikerWeb, :live_view

  alias Zippiker.Crm

  @colors ~w(slate blue violet amber emerald rose orange teal)a

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "Pipeline", colors: @colors) |> load()}
  end

  @impl true
  def handle_event("save_stage", %{"stage_id" => id, "stage" => params}, socket) do
    opts = ash_opts(socket)
    stage = Ash.get!(Crm.Stage, id, opts)

    case Crm.update_stage(stage, Map.take(params, ["name", "probability", "color"]), opts) do
      {:ok, _} -> {:noreply, socket |> put_flash(:info, "Stage saved") |> load()}
      {:error, error} -> {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event(
        "add_stage",
        %{"pipeline_id" => pipeline_id, "new_stage" => %{"name" => name}},
        socket
      ) do
    opts = ash_opts(socket)
    pipeline = Enum.find(socket.assigns.pipelines, &(&1.id == pipeline_id))
    # New stages go right before Won/Lost.
    closing = Enum.filter(pipeline.stages, &(&1.kind != :open))
    position = Enum.count(pipeline.stages, &(&1.kind == :open))

    result =
      Ash.transact(Crm.Stage, fn ->
        Enum.each(closing, &Crm.update_stage!(&1, %{position: &1.position + 1}, opts))

        Crm.create_stage!(
          %{pipeline_id: pipeline_id, name: name, position: position, probability: 50},
          opts
        )
      end)

    case result do
      {:ok, _} -> {:noreply, socket |> put_flash(:info, "Stage added") |> load()}
      {:error, error} -> {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  def handle_event("delete_stage", %{"id" => id}, socket) do
    opts = ash_opts(socket)
    stage = Ash.get!(Crm.Stage, id, opts)

    case Crm.delete_stage(stage, opts) do
      :ok ->
        {:noreply, socket |> put_flash(:info, "Stage deleted") |> load()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Move this stage's deals elsewhere first.")}
    end
  end

  defp load(socket), do: assign(socket, :pipelines, Crm.list_pipelines!(ash_opts(socket)))
end
