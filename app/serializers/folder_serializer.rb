class FolderSerializer
  def initialize(folder)
    @folder = folder
  end

  def as_json(*)
    {
      id: folder.id,
      name: folder.name,
      position: folder.position,
      created_at: timestamp(folder.created_at),
      updated_at: timestamp(folder.updated_at)
    }
  end

  private
    attr_reader :folder

    def timestamp(value)
      value&.utc&.iso8601
    end
end
