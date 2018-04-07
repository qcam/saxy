defmodule Saxy.ParserTest do
  use ExUnit.Case

  import Saxy.Parser, only: [parse_document: 3]

  alias Saxy.TestHandlers.StackHandler

  test "streaming parsing" do
    buffer = ""
    stream = File.stream!("./test/support/fixture/food.xml", [], 200)
    state = %Saxy.State{user_state: [], handler: StackHandler, prolog: [], expand_entity: :keep}

    assert {:ok, state} = parse_document(buffer, stream, state)

    assert length(state) == 74

    buffer = ""
    stream = File.stream!("./test/support/fixture/complex.xml", [], 200)
    state = %Saxy.State{user_state: [], handler: StackHandler, prolog: [], expand_entity: :keep}

    assert {:ok, state} = parse_document(buffer, stream, state)

    assert length(state) == 79
  end

  test "binary parsing" do
    buffer = File.read!("./test/support/fixture/food.xml")
    state = %Saxy.State{user_state: [], handler: StackHandler, prolog: [], expand_entity: :keep}

    assert {:ok, state} = parse_document(buffer, :done, state)

    assert length(state) == 74

    buffer = File.read!("./test/support/fixture/complex.xml")
    state = %Saxy.State{user_state: [], handler: StackHandler, prolog: [], expand_entity: :keep}

    assert {:ok, state} = parse_document(buffer, :done, state)

    assert length(state) == 79
  end
end
