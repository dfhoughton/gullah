# frozen_string_literal: true

require 'gullah'

class XMLish
  extend Gullah

  rule :root,      'element'
  rule :element,   'full | empty'
  rule :full,      '"<" tag attribute* ">" content* "</" tag ">"', preconditions: %i[same_tag]
  rule :empty,     '"<" tag attribute* "/>"'
  rule :content,   'element | text | entity', tests: %i[has_parent]
  rule :attribute, 'tag "=" value'
  rule :value,     'squote | dquote'

  leaf :tag,    /\b[a-z]+\b/
  leaf :text,   /[^&<>]+/
  leaf :entity, /&(?:[lg]t|amp|[lr]dquo);/
  leaf :squote, /'[^']*'/
  leaf :dquote, /"[^"]*"/

  def same_tag(_name, children)
    first, last = children.select { |c| c.name == :tag }
    first.text == last.text
  end

  def has_parent(_root, _node)
    :pass
  end
end

[
  '<root/>',
  '<root>some text &ldquo;thing&rdquo; and more text</root>',
  '<foo>I have</foo><bar>no root</bar>',
  '<foo attibutes="!"><and><nested/></and></foo>'
  # this next one is r-e-a-l-l-y s-l-o-o-o-o-o-w
  # '<big i="have" some="attributes"><empty/>text<element also="attributes">with<things/>inside</element></big>'
].each_with_index do |xml, i|
  parse = XMLish.parse(xml).min_by { |p| [p.length, p.size] }
  puts parse.summary
  Gullah::Dotifier.dot parse, "xml#{i}", make_it: :so
end
