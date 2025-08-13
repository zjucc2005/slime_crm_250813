# encoding: utf-8
class LocationDataController < ApplicationController
  load_and_authorize_resource
  before_action :authenticate_user!

  # GET /location_data?level=0
  def index
    if params[:parent_id].present?
      load_each_level
      @location_data = LocationDatum.where(level: params[:level], parent_id: params[:parent_id])
    else
      @location_data = LocationDatum.where(level: params[:level] || 0)
    end
  end

  # GET /location_data/autocomplete_city.json
  def autocomplete_city
    @cities = LocationDatum.cities.where("name LIKE ?", "%#{params[:term].strip}%")
    render :json => @cities.map{ |city|
      if LocationDatum::DIRECT_CODE.include?(city.code[0, 2])
        city.name
      else
        "#{city.parent.name}#{city.name}"
      end
    }
  end

  # GET /candidates/show_phone_location.json
  def show_phone_location
    data = LocationDatum.mobile_location(params[:phone])
    res = data.present? ? { status: '0', city: data[0], type: data[1] } : { status: '1' }
    render :json => res.to_json
  end

  # GET, js
  def load_children
    @province = LocationDatum.provinces.where(id: params[:ld_province_id]).first
    @city_options = '<option value>Please select</option>'
    if @province
      @cities = @province.direct_children
      @city_options += @cities.map { |city| "<option value=\"#{city.id}\">#{city.name}</option>" }.join
      if @cities && @cities.exists?(id: params[:ld_city_id])
        @ld_city_id = params[:ld_city_id]
      end
    else
      LocationDatum.provinces.each do |province|
        @city_options += province.direct_children.map { |city| "<option value=\"#{city.id}\">#{city.name}</option>" }.join
      end
      if LocationDatum.exists?(id: params[:ld_city_id])
        @ld_city_id = params[:ld_city_id]
      end
    end
    respond_to { |f| f.js }
  end

  # GET, json
  def province_options
    query = LocationDatum.provinces
    query = query.where('name ILIKE ?', "%#{params[:name].strip}%") if params[:name].present?
    @data = query.order(code: :asc).map { |item| { id: item.id, name: item.name } }
    render json: @data.to_json
  end

  private
  def load_each_level
    @parent = LocationDatum.find(params[:parent_id])

    instance_variable_set("@level_#{@parent.level}", @parent)
    if @parent.level > 0
      1.upto(@parent.level) do |i|
        instance_variable_set("@level_#{@parent.level - i}",  instance_variable_get("@level_#{@parent.level - i + 1}").parent)
      end
    end
  end

end