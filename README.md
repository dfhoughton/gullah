# gullah

A simple, fault-tolerant bottom-up parser written in Ruby.

# Synopsis

```ruby
  class Cat
    extend Gullah

    rule :S, 'NP VP'
    rule :NP, 'D NB'
    rule :NB, 'A* N'
    rule :VP, 'VP PP'
    rule :VP, 'V'
    rule :PP, 'P NP'
    rule :P, 'prepositions'
    rule :V, 'verbs'
    rule :D, 'determiners'
    rule :N, 'nouns'
    rule :A, 'adjectives'

    leaf :determiners, /\b(the|a)\b/i
    leaf :nouns, /\b(cat|mat)\b/i
    leaf :prepositions, /\b(on|in|around|above|beside)\b/i
    leaf :verbs, /\b(sat|slept|moped)\b/
    leaf :adjectives, /\b(big|small|hairy|bald)\b/i
    leaf :whatever, /\W+/, ignorable: true
  end

  def test_cat
    parses = Cat.parse 'The cat sat on the mat.'
    assert_equal 1, parses.length, 'there is only one parse of this sentence'
    parse = parses.first
    assert_equal 1, parse.nodes.reject(&:ignorable?).count, 'there is a root node for this parse'
    root = parse.nodes.first
    assert_equal :S, root.name, 'the root node is a sentence'
    vp = root.descendants.find { |d| d.name == :VP }&.descendants&.find { |d| d.name == :V }
    assert_equal 'sat', vp&.own_text, 'we have the expected verb'
  end
```

# Name

[Gullah](https://en.wikipedia.org/wiki/Gullah_language) is a [creole](https://en.wikipedia.org/wiki/Gullah_language)
spoken on the barrier islands off the coast of the Carolinas and Georgia. I wanted to call this gem "creole" because I've
written a more impoverished parser called [pidgin](https://github.com/dfhoughton/pidgin). A
[pidgin](https://en.wikipedia.org/wiki/Pidgin) is a somewhat impoverished language created as a minimal medium
of communication between two groups without a common language. A creole is a complete language created from a pidgin
when children adopt it as their primary language. The pidgin library I wrote is minimal in that it cannot handle
recursive structures. I wanted to create a better parser that could handle all the complexity of natural (or artificial)
languages. Since this was an evolution from pidgin, I wanted to call it creole.

Well, "creole" was taken. So I chose among the names of creoles of I knew of. Gullah is a creole of English and various
Central and West African languagees. I thought the name "Gullah" was cool and I like the way Gullah sounds, so I picked "Gullah".

I hope this causes no offense to speakers of Gullah.

# Further

This is very much a work in progress. For one thing, I haven't finished writing this README and the test suite is
still impoverished. I am not currently aware of any bugs, though, and I should have things patched up shortly.

