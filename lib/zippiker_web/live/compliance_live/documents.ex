defmodule ZippikerWeb.ComplianceLive.Documents do
  @moduledoc "Statutory documents library: certificate of incorporation, articles, CR12, receipts…"
  use ZippikerWeb, :live_view

  alias Zippiker.Compliance
  alias ZippikerWeb.ComplianceLive.Scope

  @kinds [
    {"Certificate of incorporation", "incorporation_certificate"},
    {"Memorandum & articles", "articles"},
    {"CR12 / official search", "cr12"},
    {"Annual return & receipt", "annual_return"},
    {"Signed minutes", "minutes"},
    {"Resolution", "resolution"},
    {"Share certificate", "share_certificate"},
    {"Beneficial ownership filing", "beneficial_ownership"},
    {"Tax (KRA)", "tax"},
    {"Other", "other"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Statutory documents", kinds: @kinds)
     |> allow_upload(:file,
       accept: ~w(.pdf .jpg .jpeg .png .doc .docx),
       max_entries: 1,
       max_file_size: 20_000_000
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = socket |> Scope.assign_profile(params) |> load()
    {:noreply, assign(socket, :modal, params["modal"])}
  end

  defp load(%{assigns: %{profile: nil}} = socket), do: assign(socket, :documents, [])

  defp load(socket),
    do:
      assign(
        socket,
        :documents,
        Compliance.statutory_documents!(socket.assigns.profile.id, ash_opts(socket))
      )

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("upload", %{"document" => params}, socket) do
    organization_id = socket.assigns.current_organization.id

    case consume_uploaded_entries(socket, :file, fn %{path: path}, entry ->
           {:ok,
            {entry.client_name,
             ZippikerWeb.Uploads.store(path, organization_id, "statutory", entry.client_name)}}
         end) do
      [{file_name, stored}] ->
        params =
          params
          |> Map.reject(fn {_key, value} -> value == "" end)
          |> Map.merge(%{
            "profile_id" => socket.assigns.profile.id,
            "file_name" => file_name,
            "path" => stored
          })
          |> Map.put_new("name", file_name)

        case Compliance.add_statutory_document(params, ash_opts(socket)) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Document saved")
             |> push_patch(to: ~p"/compliance/documents")}

          {:error, error} ->
            {:noreply, put_flash(socket, :error, error_message(error))}
        end

      [] ->
        {:noreply, put_flash(socket, :error, "Choose a file to upload")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    document = Enum.find(socket.assigns.documents, &(&1.id == id))
    :ok = Compliance.delete_statutory_document(document, ash_opts(socket))
    {:noreply, socket |> put_flash(:info, "Document removed") |> load()}
  end

  defp kind_label(kind),
    do: Enum.find_value(@kinds, "Other", fn {label, key} -> key == to_string(kind) && label end)
end
