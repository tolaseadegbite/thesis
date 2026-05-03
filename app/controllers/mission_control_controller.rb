class MissionControlController < ApplicationController
  http_basic_authenticate_with(
    name: Rails.application.credentials.dig(:mission_control, :username),
    password: Rails.application.credentials.dig(:mission_control, :password)
  )
end
