xml = File.read!("./rss.txt")

Benchee.run(%{
  "saxy"    => fn -> {:ok, _} = Saxy.SimpleForm.parse_string(xml) end,
  "erlsom" => fn -> {:ok, _, _} = :erlsom.simple_form(xml) end
}, time: 5)
