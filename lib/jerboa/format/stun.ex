defmodule Jerboa.Format.STUN do
  @moduledoc """
  Utility functions related to STUN messages
  """

  alias Jerboa.Format.STUN.{Bare, Message, DecodeError}

  @doc """
  Decodes given binary into `Jerboa.Format.STUN.Message`

  For the list of supported STUN methods see `Jerboa.Format.STUN.Method`

  If the given binary is longer than specified than in STUN header,
  function returns three-element tuple, where last element is extra
  part of binary.

  ## Examples

      iex> Jerboa.Format.STUN.decode <<0::159>>
      {:error, %Jerboa.Format.STUN.DecodeError{format: "Invalid header length"}}
      iex> Jerboa.Format.STUN.decode <<1::16, 0::16, (554_869_826)::32, 0::96>>
      {:ok, %Jerboa.Format.STUN.Message{class: :request, t_id: 0, method: :binding}}
      iex> Jerboa.Format.STUN.decode <<1::16, 0::16, (554_869_826)::32, 0::96, 128::20>>
      {:ok,
       %Jerboa.Format.STUN.Message{class: :request, method: :binding, t_id: 0},
       <<128::20>>}
      iex> Jerboa.Format.STUN.decode <<2::16, 0::16, (554_869_826)::32, 0::96>>
      {:error, %Jerboa.Format.STUN.DecodeError{method: "is unknown"}}
  """
  @spec decode(packet :: binary) :: {:ok, Message.t}
                                  | {:ok, Message.t, rest :: binary}
                                  | {:error, DecodeError.t}
  def decode(packet) do
    with {:ok, bare, rest} <- Bare.decode(packet),
         {:ok, message}    <- Message.from_bare(bare) do
      maybe_with_rest(message, rest)
    else
      {:error, _reason} = error ->
        error
    end
  end

  defp maybe_with_rest(message, <<>>), do: {:ok, message}
  defp maybe_with_rest(message, rest), do: {:ok, message, rest}

  @doc """
  Returns value of STUN magic cookie
  """
  @spec magic :: 554_869_826
  def magic, do: 554_869_826

end
