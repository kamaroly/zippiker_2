defmodule ZippikerWeb.LeaveAttachmentController do
  @moduledoc """
  Downloads HR files (leave supporting documents, checklist attachments)
  for members of the workspace they belong to.
  """
  use ZippikerWeb, :controller

  def show(conn, %{"id" => id}) do
    with %{} = user <- conn.assigns[:current_user],
         {organization, _role} <-
           ZippikerWeb.LiveUserAuth.current_workspace(user, get_session(conn, :organization_id)),
         {:ok, %{attachment_path: path} = request} when is_binary(path) <-
           Zippiker.HR.get_leave_request(id, actor: user, tenant: organization),
         full = ZippikerWeb.Uploads.full_path(path),
         true <- File.exists?(full) do
      send_download(conn, {:file, full}, filename: request.attachment_name, disposition: :inline)
    else
      _ -> not_found(conn)
    end
  end

  def checklist(conn, %{"id" => id}) do
    with %{} = user <- conn.assigns[:current_user],
         {organization, _role} <-
           ZippikerWeb.LiveUserAuth.current_workspace(user, get_session(conn, :organization_id)),
         {:ok, attachment} <-
           Zippiker.HR.get_checklist_attachment(id, actor: user, tenant: organization),
         full = ZippikerWeb.Uploads.full_path(attachment.path),
         true <- File.exists?(full) do
      send_download(conn, {:file, full}, filename: attachment.name, disposition: :inline)
    else
      _ -> not_found(conn)
    end
  end

  def statutory(conn, %{"id" => id}) do
    with %{} = user <- conn.assigns[:current_user],
         {organization, _role} <-
           ZippikerWeb.LiveUserAuth.current_workspace(user, get_session(conn, :organization_id)),
         {:ok, document} <-
           Zippiker.Compliance.get_statutory_document(id, actor: user, tenant: organization),
         full = ZippikerWeb.Uploads.full_path(document.path),
         true <- File.exists?(full) do
      send_download(conn, {:file, full}, filename: document.file_name, disposition: :inline)
    else
      _ -> not_found(conn)
    end
  end

  defp not_found(conn), do: conn |> put_status(:not_found) |> text("Not found")
end
