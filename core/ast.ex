defmodule UltraDark.AST do
  require IEx
  # Gamma costs are broken out into the following sets, with each item in @base costing
  # 2 gamma, each in @low costing 3, @medium costing 5 and @medium_high costing 6
  @base [:^, :==, :!=, :===, :!==, :<=, :<, :>, :>=, :instanceof, :|, :&, :"<<", :">>", :">>>", :in]
  @low [:+, :-]
  @medium [:*, :/, :%]
  @medium_high [:++, :--]

  @doc """
    AST lets us analyze the structure of the contract, this is used to determine
    the computational intensity needed to run the contract
  """
  @spec generate_from_source(String.t) :: Map
  def generate_from_source(source) do
    Execjs.eval("var e = require('esprima'); e.parse(`#{source}`)")
    |> ESTree.Tools.ESTreeJSONTransformer.convert
  end

  @doc """
    Recursively traverse the AST generated by ESTree, and add a call to the charge_gamma
    function before each computation.
  """
  @spec remap_with_gamma(ESTree.Program) :: list
  def remap_with_gamma(map) when is_map(map) do
    cond do
      Map.has_key?(map, :body) ->
        %{map | body: remap_with_gamma(map.body)}
      Map.has_key?(map, :value) ->
        %{map | value: remap_with_gamma(map.value)}
      true ->
        map
    end
  end

  def remap_with_gamma([component | rest], new_ast \\ []) do
    comp = remap_with_gamma(component)
    new_ast = [comp | new_ast]

    case comp do
      %ESTree.MethodDefinition{} -> remap_with_gamma(rest, new_ast)
      %ESTree.ClassDeclaration{} -> remap_with_gamma(rest, new_ast)
      _ -> remap_with_gamma(rest, [generate_gamma_charge(comp) | new_ast])
    end
  end

  def remap_with_gamma([], new_ast), do: new_ast

  def generate_gamma_charge(computation) do
    computation
    |> gamma_for_computation
    |> IO.inspect
    |> (&(generate_from_source("UltraDark.Contract.charge_gamma(#{&1})").body)).()
    |> List.first
  end

  def gamma_for_computation(%ESTree.BinaryExpression{ operator: operator }), do: compute_gamma_for_operator(operator)
  def gamma_for_computation(%ESTree.UpdateExpression{ operator: operator }), do: compute_gamma_for_operator(operator)
  def gamma_for_computation(%ESTree.ExpressionStatement{ expression: expression }), do: gamma_for_computation(expression)
  def gamma_for_computation(%ESTree.ReturnStatement{ argument: argument }), do: gamma_for_computation(argument)
  def gamma_for_computation(%ESTree.VariableDeclaration{ declarations: declarations }), do: gamma_for_computation(declarations)
  def gamma_for_computation(%ESTree.VariableDeclarator{ init: %{ value: value } }), do: calculate_gamma_for_declaration(value)
  def gamma_for_computation(%ESTree.CallExpression{}), do: 0

  def gamma_for_computation([first | rest]), do: gamma_for_computation(rest, [gamma_for_computation(first)])
  def gamma_for_computation([first | rest], gamma_list), do: gamma_for_computation(rest, [gamma_for_computation(first) | gamma_list])
  def gamma_for_computation([], gamma_list), do: Enum.reduce(gamma_list, fn gamma, acc -> acc + gamma end)

  def gamma_for_computation(other) do
    IO.warn "Gamma for computation not implemented for: #{other.type}"
    # IEx.pry
    0
  end

  @doc """
    Takes in a variable declaration and returns the gamma necessary to store the data
    within the contract. The cost is mapped to 2500 gamma per byte
  """
  @spec calculate_gamma_for_declaration(any) :: number
  def calculate_gamma_for_declaration(value) do
    (value |> :erlang.term_to_binary |> byte_size) * 2500 # Is there a cleaner way to calculate the memory size of any var?
  end

  @doc """
    Takes in a binary tree expression and returns the amount of gamma necessary
    in order to perform the expression
  """
  @spec compute_gamma_for_operator(atom) :: number | {:error, String.t}
  defp compute_gamma_for_operator(operator) do
    case operator do
      op when op in @base -> 2
      op when op in @low -> 3
      op when op in @medium -> 5
      op when op in @medium_high -> 6
      op -> {:error, "No compute_binary_or_update_expression_gamma defined for operator: #{op}"}
    end
  end

end
