# frozen_string_literal: true

class EventStreamsController < ApplicationController
  include ActionController::Live

  def test
    begin
      response.headers['Content-Type'] = 'text/event-stream'
      100.times { |i|
        response.stream.write "event: message\n"
        response.stream.write "data: hello world #{i}\n\n"
        sleep 2
      }
    ensure
      response.stream.close
    end
  end
end