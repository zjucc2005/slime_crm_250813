# encoding: utf-8
class ProjectCandidatesController < ApplicationController
  load_and_authorize_resource
  before_action :authenticate_user!

  # PUT /project_candidates/:id/update_mark.js, remote: true
  def update_mark
    load_project_candidate
    if @project_candidate.category == 'client'
      if params[:mark] == 'main'
        @project_candidate.project.project_candidates.client.where(mark: 'main').map { |pc| pc.update(mark: 'normal') }
      end
      @project_candidate.update(mark: params[:mark])
    else
      @project_candidate.update(mark: params[:mark])
    end
    respond_to{ |f| f.js }
  end

  private
  def load_project_candidate
    @project_candidate = ProjectCandidate.find(params[:id])
  end

end