# encoding: utf-8
class SearchAliasesController < ApplicationController
  load_and_authorize_resource
  before_action :authenticate_user!

  # GET /search_aliases
  def index
    query = SearchAlias.all
    query = query.where('name ILIKE ? OR kwlist @> ?', params[:name].strip, params[:name].strip.to_json) if params[:name].present?
    @search_aliases = query.order(:created_at => :desc).paginate(:page => params[:page], :per_page => 20)
  end

  # GET /search_aliases/new
  def new
    @search_alias = SearchAlias.new
  end

  # POST /search_aliases
  def create
    @search_alias = SearchAlias.new(search_alias_params)

    if @search_alias.save
      flash[:success] = t(:operation_succeeded)
      redirect_to search_aliases_path
    else
      render :new
    end
  end

  # GET /search_aliases/:id/edit
  def edit
    load_search_alias
  end

  # PUT /search_aliases/:id
  def update
    load_search_alias

    if @search_alias.update(search_alias_params)
      flash[:success] = t(:operation_succeeded)
      redirect_to search_aliases_path
    else
      render :edit
    end
  end

  # DELETE /search_aliases/:id
  def destroy
    load_search_alias

    if @search_alias.destroy
      flash[:success] = t(:operation_succeeded)
    else
      flash[:error] = t(:operation_failed)
    end
    redirect_to search_aliases_path
  end

  private
  def search_alias_params
    params.require(:search_alias).permit(:name, :kwlist)
  end

  def load_search_alias
    @search_alias = SearchAlias.find(params[:id])
  end
end