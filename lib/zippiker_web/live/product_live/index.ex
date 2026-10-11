defmodule ZippikerWeb.ProductLive.Index do
  @moduledoc "Product & service catalog."
  use ZippikerWeb, :live_view

  alias Zippiker.{Catalog, Extensibility}

  @impl true
  def mount(_params, _session, socket) do
    opts = ash_opts(socket)

    {:ok,
     socket
     |> assign(:page_title, "Products")
     |> assign(:filters, filterable_fields(:product, socket.assigns))
     |> assign(:definitions, Extensibility.list_custom_fields!(:product, opts))
     |> assign(
       :tax_options,
       Enum.map(
         Catalog.list_tax_rates!(opts),
         &{"#{&1.name} #{Decimal.normalize(&1.rate)}%", &1.id}
       )
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    query = params["q"] || ""
    cf = parse_custom_filters(params, socket.assigns.filters)

    page =
      Catalog.list_products!(
        %{query: query, custom_fields: cf},
        ash_opts(socket) ++
          [page: [limit: 25, offset: (page_param(params) - 1) * 25, count: true]]
      )

    {:noreply,
     socket
     |> assign(query: query, cf: cf, page: page)
     |> stream(:products, page.results, reset: true)
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    default_tax =
      Enum.find_value(Catalog.list_tax_rates!(ash_opts(socket)), &(&1.default? && &1.id))

    form =
      Catalog.Product
      |> AshPhoenix.Form.for_create(:create,
        as: "product",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{"tax_rate_id" => default_tax}
      )
      |> to_form()

    assign(socket, form: form, product: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    product = Catalog.get_product!(id, ash_opts(socket))

    form =
      product
      |> AshPhoenix.Form.for_update(:update,
        as: "product",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization
      )
      |> to_form()

    assign(socket, form: form, product: product)
  end

  defp apply_action(socket, :index, _params), do: assign(socket, form: nil, product: nil)

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: products_path(%{q: query, cf: socket.assigns.cf}))}
  end

  def handle_event("filter_cf", %{"cf" => cf}, socket) do
    {:noreply, push_patch(socket, to: products_path(%{q: socket.assigns.query, cf: cf}))}
  end

  def handle_event("validate", %{"product" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"product" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, product} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{product.name} saved")
         |> push_patch(to: products_path(%{q: socket.assigns.query, cf: socket.assigns.cf}))}

      {:error, form} ->
        case change_requested(form) do
          nil ->
            {:noreply, assign(socket, :form, form)}

          number ->
            {:noreply,
             socket
             |> put_flash(:info, change_requested_message(number))
             |> push_patch(to: products_path(%{q: socket.assigns.query, cf: socket.assigns.cf}))}
        end
    end
  end

  def handle_event("archive", %{"id" => id}, socket) do
    opts = ash_opts(socket)

    message =
      case id |> Catalog.get_product!(opts) |> Catalog.archive_product(opts) do
        :ok -> {:info, "Product archived"}
        {:error, error} -> held_message(error)
      end

    {:noreply,
     socket
     |> put_flash(elem(message, 0), elem(message, 1))
     |> push_patch(to: products_path(%{q: socket.assigns.query, cf: socket.assigns.cf}))}
  end

  defp held_message(error) do
    case change_requested(error) do
      nil -> {:error, error_message(error)}
      number -> {:info, change_requested_message(number)}
    end
  end

  defp products_path(params), do: query_path(~p"/products", params)
end
