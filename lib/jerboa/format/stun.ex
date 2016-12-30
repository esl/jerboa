defmodule Jerboa.Format.STUN do
  @moduledoc """
  Utility functions related to STUN messages
  """

  alias Jerboa.Format.STUN.{Bare, Message, DecodeError}

  @doc """
  Decodes given binary into `Jerboa.Format.STUN.Message`

  ## Examples

      iex> Jerboa.Format.STUN.decode <<0::159>>
      {:error, %Jerboa.Format.STUN.DecodeError{format: "Invalid header length"}}
      iex> Jerboa.Format.STUN.decode <<0::32, (554_869_826)::32, 0::96>>
      {:ok, %Jerboa.Format.STUN.Message{class: :request, t_id: 0}}
  """
  @spec decode(packet :: binary) :: {:ok, Message.t} | {:error, DecodeError.t}
  def decode(packet) do
    case Bare.decode(packet) do
      {:ok, bare} ->
        Message.from_bare(bare)
      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Returns value of STUN magic cookie
  """
  @spec magic :: 554_869_826
  def magic, do: 554_869_826

end
