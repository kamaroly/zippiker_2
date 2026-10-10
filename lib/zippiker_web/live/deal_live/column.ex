defmodule ZippikerWeb.DealLive.Column do
  @moduledoc """
  One board column. Owns a stream of its deals so a move only re-renders the
  two columns involved. The parent pushes fresh data with `send_update/2`.
  """
  use ZippikerWeb, :live_component

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, :stage, assigns.stage) |> assign(:id, assigns.id)

    socket =
      case assigns do
        %{deals: deals} when is_list(deals) -> stream(socket, :deals, deals, reset: true)
        _ -> socket
      end

    {:ok, socket}
  end
end
