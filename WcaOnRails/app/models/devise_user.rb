class DeviseUser < ActiveRecord::Base
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable

  def results_team_member?
    return true # TODO
  end
end