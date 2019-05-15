defmodule Contentful.Delivery do
  @moduledoc """
  A HTTP client for Contentful.
  This module contains the functions to interact with Contentful's read-only
  Content Delivery API.
  """

  require Logger
  use HTTPoison.Base

  @delivery_endpoint "cdn.contentful.com"
  @preview_endpoint "preview.contentful.com"
  @protocol "https"

  def space(space_id, access_token) do
    space_url = "/spaces/#{space_id}"

    contentful_request(
      space_url,
      access_token
    )
  end

  def entries(space_id, access_token, params \\ %{}) do
    entries_url = "/spaces/#{space_id}/entries"

    with {:ok, body} <-
           contentful_request(entries_url, access_token, Map.delete(params, :resolve_includes)) do
      parse_entries(body, params)
    else
      error -> error
    end
  end

  def entry(space_id, access_token, entry_id, params \\ %{}) do
    with {:ok, %{:items => [first | _]}} <-
           entries(space_id, access_token, Map.merge(params, %{:"sys.id" => entry_id})) do
      {:ok, first}
    else
      error -> error
    end
  end

  def assets(space_id, access_token, params \\ %{}) do
    assets_url = "/spaces/#{space_id}/assets"

    contentful_request(
      assets_url,
      access_token,
      params
    )
  end

  def asset(space_id, access_token, asset_id, params \\ %{}) do
    asset_url = "/spaces/#{space_id}/assets/#{asset_id}"

    contentful_request(
      asset_url,
      access_token,
      params
    )
  end

  def content_types(space_id, access_token, params \\ %{}) do
    content_types_url = "/spaces/#{space_id}/content_types"

    contentful_request(
      content_types_url,
      access_token,
      params
    )
  end

  def content_type(space_id, access_token, content_type_id, params \\ %{}) do
    content_type_url = "/spaces/#{space_id}/content_types/#{content_type_id}"

    contentful_request(
      content_type_url,
      access_token,
      params
    )
  end

  defp parse_entries(body, %{:resolve_includes => _}) do
    {:ok, Contentful.IncludeResolver.resolve_entry(body)}
  end

  defp parse_entries(body, _), do: {:ok, body}

  defp contentful_request(uri, access_token, params \\ %{}) do
    final_url = format_path(path: uri, params: params)

    Logger.debug(fn ->
      "GET #{final_url}"
    end)

    case get(final_url, client_headers(access_token)) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, :not_found}

      {:ok, %HTTPoison.Response{status_code: 401}} ->
        {:error, :not_authorized}

      {:error, %HTTPoison.Error{} = error} ->
        {:error, error}
    end
  end

  defp client_headers(access_token) do
    [
      {"authorization", "Bearer #{access_token}"},
      {"Accept", "application/json"},
      {"User-Agent", "Contentful-Elixir"}
    ]
  end

  defp format_path(path: path, params: params) do
    if Enum.any?(Map.delete(params, :preview)) do
      query =
        Map.delete(params, :preview)
        |> Enum.reduce("", fn {k, v}, acc -> acc <> "#{k}=#{v}&" end)
        |> String.trim_trailing()
      if get_in(params, [:preview]) do
        "#{@preview_endpoint}#{path}/?#{query}"
        else
        "#{@delivery_endpoint}#{path}/?#{query}"
      end
    else
      if get_in(params, [:preview]) do
        "#{@preview_endpoint}/#{path}"
      else
        "#{@delivery_endpoint}/#{path}"
      end
    end
  end

  defp process_url(url) do
    "#{@protocol}://#{url}"
  end

  defp process_response_body(body) do
    body
    |> Jason.decode!(keys: :atoms)
  end
end
