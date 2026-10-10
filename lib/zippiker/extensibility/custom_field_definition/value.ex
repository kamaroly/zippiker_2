defmodule Zippiker.Extensibility.CustomFieldDefinition.Value do
  @moduledoc """
  Casts raw (usually form) input into the JSON value stored for a custom field.
  Returns `:keep` when the field was not submitted, so partial updates and
  programmatic creates leave existing values alone.
  """

  @email ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/
  @url ~r/^https?:\/\/[^\s]+\.[^\s]+$/i

  def cast(_definition, _raw, false = _submitted?), do: :keep

  def cast(definition, raw, true) do
    case {blank?(raw), definition.required?} do
      {true, true} -> {:error, "#{definition.label} is required"}
      {true, false} -> {:ok, nil}
      {false, _} -> cast_type(definition.type, normalize(raw), definition)
    end
  end

  defp cast_type(type, value, definition) when type in [:text, :long_text] do
    max = if type == :text, do: 255, else: 10_000

    if String.length(value) <= max,
      do: {:ok, value},
      else: {:error, "#{definition.label} must be at most #{max} characters"}
  end

  defp cast_type(:number, value, _definition) when is_number(value), do: {:ok, value}

  defp cast_type(:number, value, definition) do
    case Float.parse(String.replace(value, ",", "")) do
      {number, ""} -> {:ok, if(number == trunc(number), do: trunc(number), else: number)}
      _ -> {:error, "#{definition.label} must be a number"}
    end
  end

  defp cast_type(:boolean, value, _definition) when is_boolean(value), do: {:ok, value}
  defp cast_type(:boolean, value, _definition), do: {:ok, value in ["true", "on", "1", "yes"]}

  defp cast_type(:date, %Date{} = value, _definition), do: {:ok, Date.to_iso8601(value)}

  defp cast_type(:date, value, definition) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, Date.to_iso8601(date)}
      _ -> {:error, "#{definition.label} must be a valid date"}
    end
  end

  defp cast_type(:select, value, definition) do
    if value in definition.options,
      do: {:ok, value},
      else: {:error, "#{definition.label} must be one of: #{Enum.join(definition.options, ", ")}"}
  end

  defp cast_type(:multi_select, values, definition) do
    values = values |> List.wrap() |> Enum.reject(&(&1 == ""))

    case values -- definition.options do
      [] -> {:ok, values}
      invalid -> {:error, "#{definition.label} has invalid options: #{Enum.join(invalid, ", ")}"}
    end
  end

  defp cast_type(:email, value, definition), do: match(@email, value, definition, "an email")

  defp cast_type(:url, value, definition),
    do: match(@url, value, definition, "a URL starting with http(s)://")

  defp match(regex, value, definition, description) do
    if Regex.match?(regex, value),
      do: {:ok, value},
      else: {:error, "#{definition.label} must be #{description}"}
  end

  defp normalize(value) when is_binary(value), do: String.trim(value)
  defp normalize(value), do: value

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(values) when is_list(values), do: Enum.all?(values, &(&1 in [nil, ""]))
  defp blank?(_value), do: false
end
