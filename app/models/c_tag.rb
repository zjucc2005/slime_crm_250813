# frozen_string_literal: true

class CTag < ApplicationRecord
  validates_presence_of :name, :path
  
end