defmodule ZippikerWeb.PartyLive.Show do
  @moduledoc "A contact or company: details, people, deals, timeline and tasks."
  use ZippikerWeb, :live_view

  alias Zippiker.{Crm, Extensibility, Parties, Purchasing, Sales}
  alias ZippikerWeb.PartyLive.Index

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    opts = ash_opts(socket)

    case Parties.get_party(id, opts ++ [load: [:employer, :owner]]) do
      {:ok, party} ->
        {:ok,
         socket
         |> assign(party: party, page_title: party.name)
         |> assign(:definitions, Extensibility.list_custom_fields!(party.kind, opts))
         |> assign(:deals, Crm.list_deals!(%{party_id: party.id}, opts))
         |> assign(:people, people(party, opts))
         |> assign_transactions(party)
         |> assign(:address_form, nil)
         |> load_addresses()}

      {:error, _} ->
        {:ok, socket |> put_flash(:error, "Record not found") |> push_navigate(to: ~p"/contacts")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  # The latest documents with this party, as customer and as supplier.
  defp assign_transactions(socket, party) do
    opts = ash_opts(socket) ++ [page: [limit: 5]]
    sales? = module?(socket.assigns, :sales)
    purchasing? = module?(socket.assigns, :purchasing)
    latest = fn enabled?, fun -> if enabled?, do: fun.().results, else: [] end

    socket
    |> assign(
      :quotes,
      latest.(sales?, fn -> Sales.list_quotes!(%{customer_id: party.id}, opts) end)
    )
    |> assign(
      :sales_orders,
      latest.(sales?, fn -> Sales.list_sales_orders!(%{customer_id: party.id}, opts) end)
    )
    |> assign(
      :invoices,
      latest.(sales?, fn -> Sales.list_invoices!(%{customer_id: party.id}, opts) end)
    )
    |> assign(
      :rfqs,
      latest.(purchasing?, fn -> Purchasing.list_rfqs!(%{supplier_id: party.id}, opts) end)
    )
    |> assign(
      :purchase_orders,
      latest.(purchasing?, fn ->
        Purchasing.list_purchase_orders!(%{supplier_id: party.id}, opts)
      end)
    )
    |> assign(
      :bills,
      latest.(purchasing?, fn -> Purchasing.list_bills!(%{supplier_id: party.id}, opts) end)
    )
  end

  @impl true
  def handle_event("archive", _params, socket) do
    case Parties.archive_party(socket.assigns.party, ash_opts(socket)) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "#{socket.assigns.party.name} archived")
         |> push_navigate(to: back_path(socket.assigns.party))}

      {:error, error} ->
        {:noreply,
         case change_requested(error) do
           nil -> put_flash(socket, :error, error_message(error))
           number -> put_flash(socket, :info, change_requested_message(number))
         end}
    end
  end

  def handle_event("new_address", _params, socket) do
    form =
      Parties.Address
      |> AshPhoenix.Form.for_create(:create,
        as: "address",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization,
        params: %{"party_id" => socket.assigns.party.id, "kind" => "main"}
      )
      |> to_form()

    {:noreply, assign(socket, :address_form, form)}
  end

  def handle_event("edit_address", %{"id" => id}, socket) do
    address = Enum.find(socket.assigns.addresses, &(&1.id == id))

    form =
      address
      |> AshPhoenix.Form.for_update(:update,
        as: "address",
        actor: socket.assigns.current_user,
        tenant: socket.assigns.current_organization
      )
      |> to_form()

    {:noreply, assign(socket, :address_form, form)}
  end

  def handle_event("validate_address", %{"address" => params}, socket) do
    {:noreply,
     assign(
       socket,
       :address_form,
       AshPhoenix.Form.validate(socket.assigns.address_form, upcase_country(params))
     )}
  end

  def handle_event("save_address", %{"address" => params}, socket) do
    params = Map.put(upcase_country(params), "party_id", socket.assigns.party.id)

    case AshPhoenix.Form.submit(socket.assigns.address_form, params: params) do
      {:ok, _address} ->
        {:noreply,
         socket
         |> assign(:address_form, nil)
         |> load_addresses()
         |> put_flash(:info, "Address saved")}

      {:error, form} ->
        {:noreply, assign(socket, :address_form, form)}
    end
  end

  def handle_event("delete_address", %{"id" => id}, socket) do
    address = Enum.find(socket.assigns.addresses, &(&1.id == id))
    if address, do: Parties.delete_address!(address, ash_opts(socket))
    {:noreply, load_addresses(socket)}
  end

  def handle_event("cancel_address", _params, socket),
    do: {:noreply, assign(socket, :address_form, nil)}

  @impl true
  def handle_info({ZippikerWeb.PartyLive.FormComponent, {:change_requested, number}}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, change_requested_message(number))
     |> push_patch(to: Index.show_path(socket.assigns.party))}
  end

  def handle_info({ZippikerWeb.PartyLive.FormComponent, {:saved, party}}, socket) do
    party = Ash.load!(party, [:employer, :owner], ash_opts(socket))

    {:noreply,
     socket
     |> assign(party: party, page_title: party.name)
     |> put_flash(:info, "Saved")
     |> push_patch(to: Index.show_path(party))}
  end

  defp load_addresses(socket),
    do:
      assign(
        socket,
        :addresses,
        Parties.list_addresses!(socket.assigns.party.id, ash_opts(socket))
      )

  defp upcase_country(%{"country" => country} = params) when is_binary(country),
    do: Map.put(params, "country", String.upcase(String.trim(country)))

  defp upcase_country(params), do: params

  defp people(%{kind: :organization} = party, opts),
    do: Parties.list_parties!(:person, %{employer_id: party.id}, opts)

  defp people(_party, _opts), do: []

  defp back_path(%{kind: :person}), do: ~p"/contacts"
  defp back_path(_), do: ~p"/companies"

  defp edit_path(%{kind: :person} = party), do: ~p"/contacts/#{party}/edit"
  defp edit_path(party), do: ~p"/companies/#{party}/edit"
end
