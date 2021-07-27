# frozen_string_literal: true

require 'minitest/autorun'

require 'gullah'
require 'byebug'
require 'json'

# :stopdoc:

# a proof of concept JSON parser
class JsonTest < Minitest::Test
  class Gson
    extend Gullah

    # NOTE: these rules have processors to simplify testing
    # this is *not* the most efficient way to deserialize the JSON string
    # better would be to convert the AST after parsing

    rule :object, '"{" key_value_pair* last_pair? "}"', process: :objectify
    rule :last_pair, 'string ":" json', process: :inherit_json_value
    rule :key_value_pair, 'string ":" json ","', process: :inherit_json_value
    rule :array, '"[" array_item* json? "]"', process: :arrayify
    rule :json, 'complex | simple', process: :inherit_value
    rule :complex, 'array | object', process: :inherit_value
    rule :array_item, 'json ","', process: :inherit_value
    rule :simple, 'string | null | integer | si | float | boolean', process: :inherit_value, tests: %i[not_key]

    leaf :boolean, /\b(true|false)\b/, process: ->(n) { n.atts[:value] = n.text == 'true' }
    leaf :string, /'(?:[^'\\]|\\.)*'/, process: :clean_string
    leaf :string, /"(?:[^"\\]|\\.)*"/, process: :clean_string
    leaf :null, /\bnull\b/, process: ->(n) { n.atts[:value] = nil }
    leaf :si, /\b\d\.\d+e[1-9]\d*\b/, process: ->(n) { n.atts[:value] = n.text.to_f }
    leaf :float, /\b\d+\.\d+\b/, process: ->(n) { n.atts[:value] = n.text.to_f }
    leaf :integer, /\b[1-9]\d*\b/, process: ->(n) { n.atts[:value] = n.text.to_i }

    def not_key(node)
      return :pass if node.children.first.name != :string

      node.full_text[node.end..-1] =~ /\A\s*:/ ? :fail : :pass
      # /\s*:/.match(node.full_text, node.end)&.begin(0) == node.end ? :fail : :pass
    end

    def inherit_json_value(node)
      node.atts[:value] = node.children.find { |n| n.name == :json }.atts[:value]
    end

    def inherit_value(node)
      node.atts[:value] = node.children.first.atts[:value]
    end

    def clean_string(node)
      text = node.text
      node.atts[:value] = text[1...(text.length - 1)].gsub(/\\(.)/, '\1')
    end

    def arrayify(node)
      node.atts[:value] = node.children.reject(&:leaf?).map do |n|
        n.subtree.find { |c| c.name == :json }.atts[:value]
      end
    end

    def objectify(node)
      node.atts[:value] = node.children.reject(&:leaf?).map do |pair|
        key, _, value = pair.children
        [key.atts[:value], value.atts[:value]]
      end.to_h
    end
  end

  def test_various
    [
      [],
      {},
      1,
      1.1,
      1.2345678901e10,
      'string',
      '"string"',
      [1],
      { 'a' => 1 },
      { 'a' => 1, 'b' => 2 },
      { 'foo' => [1, 2, true], 'bar' => ['baz'], 'baz' => { 'v1' => nil, 'v2' => [], 'v3' => 'corge' } },
      ['2', { 'a' => false }],
      [1, nil, '2', { 'a' => false }]
    ].each do |val|
      json = JSON.unparse(val)
      t1 = Time.now
      parses = Gson.parse json
      t2 = Time.now
      delta = t2.to_f - t1.to_f
      if delta > 1
        puts "#{json}: #{delta}"
      end
      assert_equal 1, parses.length, "unambiguous: #{json}"
      parse = parses.first
      root = parse.roots.first
      assert_equal val, root.atts[:value], "parsed value correctly: #{json}"
    end
  end
end
