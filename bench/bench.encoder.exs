bench_options = [
  time: 5,
  memory_time: 2,
  inputs: %{
    "simple document" => :simple,
    "deeply nested elements " => :nested,
    "long content element" => :long_content
  }
]

defmodule Bench.Saxy.Builder do
  import Saxy.XML, only: [element: 3]

  def build(:simple) do
    element("root", [], [
      element("element1", [], []),
      element(
        "element2",
        [],
        Enum.map(0..9, fn index ->
          element("element2.#{index}", [], "foo")
        end)
      ),
      element("element3", [], [])
    ])
  end

  def build(:nested) do
    Enum.reduce(1000..1, "content", fn index, acc ->
      element("element.#{index}", [], acc)
    end)
  end

  # Make them available in compile time.
  @strings for _ <- 0..999, do: "Jag Älskar Sverige"
  @long_string String.duplicate("Jag Älskar Sverige", 1000)

  def build(:long_content) do
    element(
      "root",
      [],
      [
        element("many-strings", [], @strings),
        element("long-string", [], @long_string)
      ]
    )
  end
end

defmodule Bench.XMLBuilder.Builder do
  import XmlBuilder, only: [document: 3, element: 3]

  def build(:simple) do
    document("root", [], [
      element("element1", [], []),
      element(
        "element2",
        [],
        Enum.map(0..9, fn index ->
          element("element2.#{index}", [], "foo")
        end)
      ),
      element("element3", [], [])
    ])
  end

  def build(:nested) do
    document(
      "level1",
      [],
      Enum.reduce(1000..2, "content", fn index, acc ->
        [element("element.#{index}", [], acc)]
      end)
    )
  end

  # Make it available in compile time.
  @strings for _ <- 0..999, do: "Jag Älskar Sverige"
  @long_string String.duplicate("Jag Älskar Sverige", 1000)

  def build(:long_content) do
    document(
      "root",
      [],
      [
        element("many-strings", [], @strings),
        element("long-string", [], @long_string)
      ]
    )
  end
end

Benchee.run(
  %{
    "Saxy (red apple)" => fn sample ->
      sample
      |> Bench.Saxy.Builder.build()
      |> Saxy.encode!()
    end,
    "XML Builder without formatting (red apple)" => fn sample ->
      sample
      |> Bench.XMLBuilder.Builder.build()
      |> XmlBuilder.generate(format: :none)
    end,
    "XML Builder with formatting (green apple)" => fn sample ->
      sample
      |> Bench.XMLBuilder.Builder.build()
      |> XmlBuilder.generate()
    end
  },
  bench_options
)
