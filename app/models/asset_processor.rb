require 'open-uri'

class AssetProcessor

  def self.for_directory(directory)
    f = Findler.new directory
    f.append_extensions ".jpeg", ".jpg", ".cr2"
    f.case_insensitive!
    new(f.iterator)
  end

  def initialize(iterator)
    @iterator = iterator
    @asset_types = [ExifAsset]
  end

  def process
    a = iterator.next

    self.class.process(a)
  end

  def self.process(uri)
    uri = URI.parse(uri) unless uri.is_a? URI
    asset = Asset.with_uri(uri.to_s).first

    if asset.nil?
      # TODO: assumes there's only one subclass that can process a given URI -- or at least the first one wins.
      clazz = Asset.subclasses.detect { |ea| ea.can_process? uri }
      thumbprint = clazz.thumbprint(uri)
      asset = clazz.find_by_thumbprint(thumbprint)
    end

    if asset.nil?
      asset = clazz.process(:uri => uri)
    else
      asset.process(uri)
    end

    asset.child_uris.each { |ea| AssetProcessor.new(ea).process }
  end

  handle_asynchronously :process
end