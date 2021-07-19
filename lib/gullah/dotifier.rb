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
# the named argument and just generate the dot file which you can feed into
# graphviz some other way.
#
# I make no guarantees about this utility. You may want to build your own,
# in which case this may serve as a simple prototype.
module Gullah
  class Dotifier
    def self.dot(parse, file, make_it: false, type: 'png')
      new.send :dot, parse, file, make_it, type
    end

    # making the guts private to simplify the API

    private

    def dot(parse, file, make_it, type)
      @edges = {}
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
      `dot -T#{type} -o#{file}.#{type} #{file}` if make_it
    end

    def tree(node, f)
      return if node.ignorable?

      f.puts "\t#{name(node)} #{node_attributes(node)}"
      Array(node.atts[:satisfied_ancestor]).each do |_, loc, *|
        child = node.find loc
        add_edge node, child, :success, true
      end
      Array(node.atts[:failed_ancestor]).each do |_, loc, *|
        child = node.find loc
        add_edge node, child, :error, true
      end
      Array(node.children&.reject(&:ignorable?)).each do |child|
        f.puts "\t#{name(node)} -- #{name(child)}#{edge_attributes node, child}"
        tree(child, f)
      end
    end

    def add_edge(parent, child, property, value)
      while parent != child
        middle = parent.children.find { |c| c.contains? child.start }
        (@edges[[parent.position, middle.position]] ||= {})[property] = value
        parent = middle
      end
    end

    def edge_attributes(node, child)
      atts = []
      if (properties = @edges[[node.position, child.position]])
        if properties[:error]
          atts << "color=red"
        elsif properties[:success]
          atts << "color=green"
        end
      end
      " [#{atts.join(';')}]" if atts.any?
    end

    def node_attributes(node)
      atts = ["label=#{(node.leaf? ? node.text : node.name.to_s).inspect}"]
      if node.trash?
        atts << "color=red"
        atts << "shape=box"
      elsif node.error?
        atts << "color=red"
        atts << "shape=oval"
      elsif node.atts[:satisfied_ancestor] || node.atts[:satisfied_descendant]
        atts << "color=green"
        atts << "shape=oval"
      end
      "[#{atts.join(';')}]"
    end

    def name(node)
      offset, height = node.position
      "n_#{offset}_#{height}"
    end
  end
end
