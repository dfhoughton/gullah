# frozen_string_literal: true

# A little tool to help visualize a parse tree. It generates .dot files
# parsable by graphviz. If you have graphviz installed, you may be able
# to invoke it like so and generate a .png file
#
#   Gullah::Dotifier.dot parses.first, "tree", make_it: :so
#
# This will generate a file called tree.png showing the parse tree. If you
# don't have graphviz, or perhaps if you're on a machine which doesn't like
# the command this generates -- I suspect Windows doesn't -- you can skip
# the named argument and just generate the .dot file which you can feed into
# graphviz some other way.
#
# I make no guarantees about this utility. You may want to build your own,
# in which case this may serve as a simple prototype.
module Gullah
  class Dotifier
    def self.dot(parse, file, make_it: false)
      new.send :dot, parse, file, make_it
    end

    # making the guts private to simplify the API

    private

    def dot(parse, file, make_it)
      File.open file, 'w' do |f|
        f.puts 'graph {'
        f.puts "\tnode[shape=none]"
        f.puts
        parse.nodes.each do |root|
          tree(root, f)
        end
        # put all the leaves in a row at the bottom
        f.puts
        f.puts "\tsubgraph {"
        f.puts "\t\trank=\"same\""
        parse.nodes.flat_map(&:leaves).reject(&:ignorable?).each do |leaf|
          f.puts "\t\t#{name(leaf)}"
        end
        f.puts "\t}"
        f.puts '}'
      end
      `dot -Tpng -o#{file}.png #{file}` if make_it
    end

    def tree(node, f)
      return if node.ignorable?

      f.puts "\t#{name(node)} [label=#{(node.leaf? ? node.text : node.name.to_s).inspect}]"
      Array(node.children&.reject(&:ignorable?)).each do |child|
        f.puts "\t#{name(node)} -- #{name(child)}"
        tree(child, f)
      end
    end

    def name(node)
      offset, height = node.position
      "n_#{offset}_#{height}"
    end
  end
end
