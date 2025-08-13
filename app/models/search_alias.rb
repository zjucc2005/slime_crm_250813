# encoding: utf-8
class SearchAlias < ApplicationRecord
  validates_presence_of :name
  validates_uniqueness_of :name
  before_validation :setup, on: [:create, :update]

  MAX_KWLIST_LENGTH = 5

  private
  def setup
    self.name = name.try(:strip)
    if self.kwlist.is_a? String
      self.kwlist = self.kwlist.split(',').map(&:strip)
      if self.kwlist.length > MAX_KWLIST_LENGTH
        errors.add(:kwlist, :less_than_or_equal_to, :count => MAX_KWLIST_LENGTH)
      end
    else
      errors.add(:kwlist, :invalid_format)
    end
  end
end
