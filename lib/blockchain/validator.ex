defmodule UltraDark.Validator do
  alias UltraDark.Blockchain.Block, as: Block

  def is_block_valid?(block, chain) do
    last_block = List.first(chain)
    
    with :ok <- valid_index(block.index, last_block.index),
         :ok <- valid_prev_hash(block.previous_hash, last_block.hash),
         :ok <- valid_hash(block)
    do
      :ok
    else
      err -> :error
    end
  end

  defp valid_index(index, prev_index) when index > prev_index, do: :ok
  defp valid_prev_hash(prev_hash, last_block_hash) when prev_hash == last_block_hash, do: :ok

  defp valid_hash(%{index: index, previous_hash: previous_hash, timestamp: timestamp, nonce: nonce, hash: hash}) do
    if Block.calculate_hash([Integer.to_string(index), previous_hash, timestamp, Integer.to_string(nonce)]) == hash, do: :ok
  end

end
