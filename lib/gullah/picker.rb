# frozen_string_literal: true

module Gullah
  # a Picker keeps a sorted set of iterators so we can always pick the iterator
  # most likely to lead quickly to a satisfactory parse
  class Picker # :nodoc:
    def initialize
      # a sorted list of the
      @error_counts = []
      @error_lists = []
      @size_count_list = []
    end

    # add an iterator
    def <<(iterator)
      e_idx = iterator.errors
      s_idx = iterator.length
      e_list = @error_lists[e_idx] ||= []
      list = e_list[s_idx] ||= []
      sc_list = @size_count_list[e_idx] ||= []
      if (i = @error_counts.bsearch_index { |c| c >= e_idx })
        # *may* have to add this error count
        @error_counts.insert i, e_idx if @error_counts[i] != e_idx
      else
        # this is a bigger error count than we currently have
        @error_counts << e_idx
      end
      if (i = sc_list.bsearch_index { |c| c >= s_idx })
        # *may* have to add this size
        sc_list.insert i, s_idx if sc_list[i] != s_idx
      else
        # this size is bigger than we currently have for this error count
        sc_list << s_idx
      end
      # finally, we stow the iterator
      list << iterator
    end

    # remove the best iterator
    def pop
      error_idx = @error_counts.first
      return nil unless error_idx

      error_list = @error_lists[error_idx]
      size_idx = @size_count_list[error_idx].first
      size_list = error_list[size_idx]
      iterator = size_list.pop
      # remove indices if they're used up
      if size_list.empty?
        @size_count_list[error_idx].shift
        @error_counts.shift if @size_count_list[error_idx].empty?
      end
      iterator
    end
  end
end
