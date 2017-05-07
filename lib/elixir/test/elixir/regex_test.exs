Code.require_file "test_helper.exs", __DIR__

defmodule RegexTest do
  use ExUnit.Case, async: true

  doctest Regex

  test "multiline" do
    refute Regex.match?(~r/^b$/, "a\nb\nc")
    assert Regex.match?(~r/^b$/m, "a\nb\nc")
  end

  test "precedence" do
    assert {"aa", :unknown} |> elem(0) =~ ~r/(a)\1/
  end

  test "backreference" do
    assert "aa" =~ ~r/(a)\1/
  end

  test "source" do
    src = "foo"
    assert Regex.source(Regex.compile!(src)) == src
    assert Regex.source(~r/#{src}/) == src

    src = "\a\b\d\e\f\n\r\s\t\v"
    assert Regex.source(Regex.compile!(src)) == src
    assert Regex.source(~r/#{src}/) == src

    src = "\a\\b\\d\\e\f\n\r\\s\t\v"
    assert Regex.source(Regex.compile!(src)) == src
    assert Regex.source(~r/#{src}/) == src
  end

  test "literal source" do
    assert Regex.source(Regex.compile!("foo")) == "foo"
    assert Regex.source(~r"foo") == "foo"
    assert Regex.re_pattern(Regex.compile!("foo"))
           == Regex.re_pattern(~r"foo")

    assert Regex.source(Regex.compile!("\a\b\d\e\f\n\r\s\t\v")) == "\a\b\d\e\f\n\r\s\t\v"
    assert Regex.source(~r<\a\b\d\e\f\n\r\s\t\v>) == "\a\\b\\d\\e\f\n\r\\s\t\v"
    assert Regex.re_pattern(Regex.compile!("\a\b\d\e\f\n\r\s\t\v"))
           == Regex.re_pattern(~r"\a\010\177\033\f\n\r \t\v")

    assert Regex.source(Regex.compile!("\a\\b\\d\e\f\n\r\\s\t\v")) == "\a\\b\\d\e\f\n\r\\s\t\v"
    assert Regex.source(~r<\a\\b\\d\\e\f\n\r\\s\t\v>) == "\a\\\\b\\\\d\\\\e\f\n\r\\\\s\t\v"
    assert Regex.re_pattern(Regex.compile!("\a\\b\\d\e\f\n\r\\s\t\v"))
           == Regex.re_pattern(~r"\a\b\d\e\f\n\r\s\t\v")
  end

  test "Unicode" do
    assert "olá" =~ ~r"\p{Latin}$"u
    refute "£" =~ ~r/\p{Lu}/u

    # Non breaking space matches [[:space:]] with Unicode
    assert <<0xA0::utf8>> =~ ~r/[[:space:]]/u
    assert <<0xA0::utf8>> =~ ~r/\s/u

    assert <<?<, 255, ?>>> =~ ~r/<.>/
    refute <<?<, 255, ?>>> =~ ~r/<.>/u
  end

  test "ungreedy" do
    assert Regex.run(~r/[\d ]+/, "1 2 3 4 5"), ["1 2 3 4 5"]
    assert Regex.run(~r/[\d ]?+/, "1 2 3 4 5"), ["1"]
    assert Regex.run(~r/[\d ]+/U, "1 2 3 4 5"), ["1"]
  end

  test "regex?/1" do
    assert Regex.regex?(~r/foo/)
    refute Regex.regex?(0)
  end

  test "compile/1" do
    {:ok, regex} = Regex.compile("foo")
    assert Regex.regex?(regex)
    assert {:error, _} = Regex.compile("*foo")
    assert {:error, _} = Regex.compile("foo", "y")
    assert {:error, _} = Regex.compile("foo", "uy")
  end

  test "compile/1 with Erlang options" do
    {:ok, regex} = Regex.compile("foo\\sbar", [:dotall, {:newline, :anycrlf}])
    assert "foo\nbar" =~ regex
  end

  test "compile!/1" do
    assert Regex.regex?(Regex.compile!("foo"))

    assert_raise Regex.CompileError, ~r/position 0$/, fn ->
      Regex.compile!("*foo")
    end
  end

  test "recompile/1" do
    new_regex = ~r/foo/
    {:ok, regex} = Regex.recompile(new_regex)
    assert Regex.regex?(regex)
    assert Regex.regex?(Regex.recompile!(new_regex))

    old_regex = Map.delete(~r/foo/, :re_version)
    {:ok, regex} = Regex.recompile(old_regex)
    assert Regex.regex?(regex)
    assert Regex.regex?(Regex.recompile!(old_regex))
  end

  test "opts/1" do
    assert Regex.opts(Regex.compile!("foo", "i")) == "i"
  end

  test "names/1" do
    assert Regex.names(~r/(?<FOO>foo)/) == ["FOO"]
  end

  test "match?/2" do
    assert Regex.match?(~r/foo/, "foo")
    refute Regex.match?(~r/foo/, "FOO")
    assert Regex.match?(~r/foo/i, "FOO")
    assert Regex.match?(~r/\d{1,3}/i, "123")

    assert Regex.match?(~r/foo/,   "afooa")
    refute Regex.match?(~r/^foo/, "afooa")
    assert Regex.match?(~r/^foo/,  "fooa")
    refute Regex.match?(~r/foo$/, "afooa")
    assert Regex.match?(~r/foo$/,  "afoo")
  end

  test "named_captures/2" do
    assert Regex.named_captures(~r/(?<foo>c)(?<bar>d)/, "abcd") == %{"bar" => "d", "foo" => "c"}
    assert Regex.named_captures(~r/c(?<foo>d)/, "abcd") == %{"foo" => "d"}
    assert Regex.named_captures(~r/c(?<foo>d)/, "no_match") == nil
    assert Regex.named_captures(~r/c(?<foo>d|e)/, "abcd abce") == %{"foo" => "d"}
    assert Regex.named_captures(~r/c(.)/, "cat") == %{}
  end

  test "sigil R" do
    assert Regex.match?(~R/f#{1,3}o/, "f#o")
  end

  test "run/2" do
    assert Regex.run(~r"c(d)", "abcd") == ["cd", "d"]
    assert Regex.run(~r"e", "abcd") == nil
  end

  test "run/3 with :all_names as the value of the :capture option" do
    assert Regex.run(~r/c(?<foo>d)/, "abcd", capture: :all_names) == ["d"]
    assert Regex.run(~r/c(?<foo>d)/, "no_match", capture: :all_names) == nil
    assert Regex.run(~r/c(?<foo>d|e)/, "abcd abce", capture: :all_names) == ["d"]
  end

  test "run/3 with :index as the value of the :return option" do
    assert Regex.run(~r"c(d)", "abcd", return: :index) == [{2, 2}, {3, 1}]
    assert Regex.run(~r"e", "abcd", return: :index) == nil
  end

  test "scan/2" do
    assert Regex.scan(~r"c(d|e)", "abcd abce") == [["cd", "d"], ["ce", "e"]]
    assert Regex.scan(~r"c(?:d|e)", "abcd abce") == [["cd"], ["ce"]]
    assert Regex.scan(~r"e", "abcd") == []
  end

  test "scan/2 with :all_names as the value of the :capture option" do
    assert Regex.scan(~r/cd/, "abcd", capture: :all_names) == []
    assert Regex.scan(~r/c(?<foo>d)/, "abcd", capture: :all_names) == [["d"]]
    assert Regex.scan(~r/c(?<foo>d)/, "no_match", capture: :all_names) == []
    assert Regex.scan(~r/c(?<foo>d|e)/, "abcd abce", capture: :all_names) == [["d"], ["e"]]
  end

  test "split/2,3" do
    assert Regex.split(~r",", "") == [""]
    assert Regex.split(~r",", "", trim: true) == []
    assert Regex.split(~r",", "", trim: true, parts: 2) == []

    assert Regex.split(~r"=", "key=") == ["key", ""]
    assert Regex.split(~r"=", "=value") == ["", "value"]

    assert Regex.split(~r" ", "foo bar baz") == ["foo", "bar", "baz"]
    assert Regex.split(~r" ", "foo bar baz", parts: :infinity) == ["foo", "bar", "baz"]
    assert Regex.split(~r" ", "foo bar baz", parts: 10) == ["foo", "bar", "baz"]
    assert Regex.split(~r" ", "foo bar baz", parts: 2) == ["foo", "bar baz"]

    assert Regex.split(~r" ", " foo bar baz ") == ["", "foo", "bar", "baz", ""]
    assert Regex.split(~r" ", " foo bar baz ", trim: true) == ["foo", "bar", "baz"]
    assert Regex.split(~r" ", " foo bar baz ", parts: 2) == ["", "foo bar baz "]
    assert Regex.split(~r" ", " foo bar baz ", trim: true, parts: 2) == ["foo", "bar baz "]
  end

  test "split/3 with the :on option" do
    assert Regex.split(~r/()abc()/, "xabcxabcx", on: :none) ==
           ["xabcxabcx"]
    assert Regex.split(~r/()abc()/, "xabcxabcx", on: :all_but_first) ==
           ["x", "abc", "x", "abc", "x"]

    assert Regex.split(~r/(?<first>)abc(?<last>)/, "xabcxabcx", on: [:first, :last]) ==
           ["x", "abc", "x", "abc", "x"]
    assert Regex.split(~r/(?<first>)abc(?<last>)/, "xabcxabcx", on: [:last, :first]) ==
           ["xabc", "xabc", "x"]

    assert Regex.split(~r/a(?<second>b)c/, "abc", on: [:second]) ==
           ["a", "c"]
    assert Regex.split(~r/a(?<second>b)c|a(?<fourth>d)c/, "abc adc abc", on: [:second]) ==
           ["a", "c adc a", "c"]
    assert Regex.split(~r/a(?<second>b)c|a(?<fourth>d)c/, "abc adc abc", on: [:second, :fourth]) ==
           ["a", "c a", "c a", "c"]
  end

  test "split/3 with the :include_captures option" do
    assert Regex.split(~r/([ln])/, "Erlang", include_captures: true) == ["Er", "l", "a", "n", "g"]
    assert Regex.split(~r/([kw])/, "Elixir", include_captures: true) == ["Elixir"]
    assert Regex.split(~r/([Ee]lixir)/, "Elixir", include_captures: true, trim: true) == ["Elixir"]
    assert Regex.split(~r/([Ee]lixir)/, "Elixir", include_captures: true, trim: false) == ["", "Elixir", ""]
  end

  test "replace/3,4" do
    assert Regex.replace(~r(d), "abc", "d") == "abc"
    assert Regex.replace(~r(b), "abc", "d") == "adc"
    assert Regex.replace(~r(b), "abc", "[\\0]") == "a[b]c"
    assert Regex.replace(~r[(b)], "abc", "[\\1]") == "a[b]c"
    assert Regex.replace(~r[(b)], "abc", "[\\2]") == "a[]c"
    assert Regex.replace(~r[(b)], "abc", "[\\3]") == "a[]c"
    assert Regex.replace(~r(b), "abc", "[\\g{0}]") == "a[b]c"
    assert Regex.replace(~r[(b)], "abc", "[\\g{1}]") == "a[b]c"

    assert Regex.replace(~r(b), "abcbe", "d") == "adcde"
    assert Regex.replace(~r(b), "abcbe", "d", global: false) == "adcbe"

    assert Regex.replace(~r/ /, "first third", "\\second\\") ==
           "first\\second\\third"
    assert Regex.replace(~r/ /, "first third", "\\\\second\\\\") ==
           "first\\second\\third"

    assert Regex.replace(~r[a(b)c], "abcabc", fn -> "ac" end) == "acac"
    assert Regex.replace(~r[a(b)c], "abcabc", fn "abc" -> "ac" end) == "acac"
    assert Regex.replace(~r[a(b)c], "abcabc", fn "abc", "b" -> "ac" end) == "acac"
    assert Regex.replace(~r[a(b)c], "abcabc", fn "abc", "b", "" -> "ac" end) == "acac"
    assert Regex.replace(~r[a(b)c], "abcabc", fn "abc", "b" -> "ac" end, global: false) == "acabc"
  end

  test "escape" do
    assert matches_escaped?(".")
    refute matches_escaped?(".", "x")

    assert matches_escaped?("[\w]")
    refute matches_escaped?("[\w]", "x")

    assert matches_escaped?("\\")

    assert matches_escaped?("\\xff", "\\xff")
    refute matches_escaped?("\\xff", "\xff")

    assert matches_escaped?("(")
    assert matches_escaped?("()")
    assert matches_escaped?("(?:foo)")

    assert matches_escaped?("\\A  \\z")
    assert matches_escaped?("  x  ")
    assert matches_escaped?("  x    x ") # Unicode spaces here
    assert matches_escaped?("# lol")

    assert matches_escaped?("\\A.^$*+?()[{\\| \t\n\x20\\z #hello\u202F\u205F")
    assert Regex.match? Regex.compile!("[" <> Regex.escape("!-#") <> "]"), "-"

    assert Regex.escape("{}") == "\\{\\}"
    assert Regex.escape("[]") == "\\[\\]"

    assert Regex.escape("{foo}") == "\\{foo\\}"
    assert Regex.escape("[foo]") == "\\[foo\\]"
  end

  defp matches_escaped?(string) do
    matches_escaped?(string, string)
  end

  defp matches_escaped?(string, match) do
    Regex.match? ~r/#{Regex.escape(string)}/simxu, match
  end
end
