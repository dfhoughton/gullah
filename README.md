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

    leaf :determiners, /\b(the|an?)\b/i
    leaf :nouns, /\b(cat|mat)\b/i
    leaf :prepositions, /\b(on|in|around|above|beside)\b/i
    leaf :verbs, /\b(sat|slept|moped)\b/
    leaf :adjectives, /\b(big|small|hairy|bald|fat)\b/i

    ignore :whatever, /[^\w\s]+/
  end

  def test_cat
    parses = Cat.parse 'The fat cat sat on the mat.'
    assert_equal 1, parses.length, 'there is only one parse of this sentence'
    parse = parses.first
    assert_equal 1, parse.roots.reject(&:ignorable?).length, 'there is a root node for this parse'
    root = parse.roots.reject(&:ignorable?).first
    assert_equal :S, root.name, 'the root node is a sentence'
    verb = root.descendants.find { |d| d.name == :VP }&.descendants&.find { |d| d.name == :V }
    assert_equal 'sat', verb&.text, 'we have the expected verb'
  end
```

# What is this?

A parser takes a string representing some structured data -- a sentence in a natural language, say, or a data structure, or a program in some programming language -- and a set of rules defining the possible structures in this data and it returns an object representing the structured data.

A top-down parser requires some root rule that all data structures obeying these rules will obey. A bottom-up parser says for a given piece of data what rules it may participate in. A top-down parser in effect compiles into a state machine similar to a regular expression that represents all ways a string may obey its rules. It in effect constructs a parsing plan and tries to match this plan to the string. A bottom-up parser begins planning when it sees the data. It looks at the first thing it is given to match and creates a plan for matching it and whatever may follow.

The important difference is that a top-down parser must have a single root element. A bottom-up parser takes what is given and reduces it to a set of root symbols. It need not have a common symbol that must be at the root of all parses.

# Why?

I made Gullah because it seemed like a fun project. I have written several parsing-related things
for several languages. I have written a [top-down parser](https://github.com/dfhoughton/Grammar) and a [non-recursive top-down parser](https://github.com/dfhoughton/pidgin). I thought I'd try a bottom-up parser. I have no particular use for it, but I often find I want to parse things, so maybe a use will show up.

# Should I use this?

Well, it's pretty easy to use, but if you have a bespoke parser for a particular unambiguous language, that will almost certainly be much faster. An XML parser can parse XML in linear time. Because Gullah is looking for errors and ambiguity it will consider lots of alternative deadend permutations that a SAX parser, say, will skip. Don't write a new JSON parser in Gullah, in other words. But if you want to play with natural language, or you have some toy language or small spec you're working with, Gullah can get you going quickly. Maybe it will suffice for all your needs!

Gullah will give you its best parses of your string even if it is ungrammatical. Also, Gullah makes it easy to add arbitrary conditions on rules that another parser might not. For instance, in Gullah you can specify arbitrary-width lookarounds for a rule -- `foo` must be preceded/followed by `bar` and some number of whitespaces -- and you can define other long-distance dependences -- "runs" must have a singular subject, "viejas" must be modifying a feminine plural noun. For more on this see the documentation of node tests, ancestor tests, and preconditions in the `Gullah` module.

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
Central and West African languages. I thought the name "Gullah" was cool and I like the way Gullah sounds, so I picked "Gullah".

I hope this causes no offense to speakers of Gullah.

# Future

Because Gullah is designed to handle ambiguous grammars and erroneous data, it can produce many parses for a given string. Right now you can ask for all parses (maybe very slow), or at least `n` equally good parses. This makes the API a little complicated and noisy. I have begun work rewriting it to return a lazy enumeration of parses. Ruby's `Enumerable` magic is nice. I haven't finished this, though, and I might not, but it may be that some future version of this will change the API dramatically.

Another possibility, if I have sufficient spare time and am sufficiently ambitious, is that I may refactor the algorithm to use ractors. Certain parts of the algorithm are a natural fit for parallelization. We shall see.

# Acknowledgements

I would like to thank my family and co-workers for tolerating me saying "Gullah" much more often than any of them expected.

# Dedication

I dedicate this gem to my son Jude, a.k.a [TurkeyMcMac](https://github.com/TurkeyMcMac). He was a better programmer than I will ever be and was only getting better. More importantly, he was a kind, funny, thoughtful person. I miss him every day. I love you, Jude.
