defmodule ZippikerWeb.Uploads do
  @moduledoc """
  Stores uploaded files on disk under the configured `:uploads_dir`, per
  workspace, with unguessable names. Files are only served through
  controllers that check access (never from the static folder).
  """

  @doc "Copies the uploaded temp file in; returns its path relative to the uploads dir."
  def store(tmp_path, organization_id, folder, filename) do
    safe =
      filename
      |> Path.basename()
      |> String.replace(~r/[^\w.\-]+/u, "_")
      |> String.slice(-120, 120)

    relative = Path.join([organization_id, folder, "#{Ash.UUID.generate()}-#{safe}"])
    target = full_path(relative)

    File.mkdir_p!(Path.dirname(target))
    File.cp!(tmp_path, target)
    relative
  end

  @doc "Absolute path of a stored file (refuses paths escaping the uploads dir)."
  def full_path(relative) do
    root = Path.expand(Application.get_env(:zippiker, :uploads_dir, "priv/uploads"))
    path = Path.expand(relative, root)
    if String.starts_with?(path, root <> "/"), do: path, else: raise(ArgumentError, "bad path")
  end
end
