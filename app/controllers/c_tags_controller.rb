# frozen_string_literal: true

class CTagsController < ApplicationController
  load_and_authorize_resource
  before_action :authenticate_user!

  def index
    
  end
end