class UserSerializer
  def initialize(user)
    @user = user
  end

  def as_json(*)
    {
      id: user.id,
      email: user.email,
      name: user.name
    }
  end

  private
    attr_reader :user
end
