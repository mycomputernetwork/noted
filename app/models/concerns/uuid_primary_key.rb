module UuidPrimaryKey
  extend ActiveSupport::Concern

  included do
    before_create { self.id ||= SecureRandom.uuid }
  end
end
