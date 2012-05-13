require "minitest_helper"

describe "asset processing without image resizing" do
  before :each do
    ImageResizer.stubs(:visit_asset) # this takes a while, and we aren't testing it here, so skip.
    @ap = AssetProcessor.new(nil)
  end

  def process_img_2452
    p = Pathname.new("test/images/IMG_2452.jpg")
    asset = @ap.process(p)
    asset.save!
    return asset, p.realpath
  end

  it "should work on insert" do
    asset, path = process_img_2452
    asset.uri.must_equal(path.to_uri)
    asset.asset_uris.size.must_equal 1
    au = asset.asset_uris.first
    au.to_uri.must_equal(path.to_uri)
    au.uri.must_equal(path.to_uri.to_s)
  end

  it "should find the prior asset" do
    asset, path = process_img_2452
    a2 = @ap.process(path)
    a2.must_equal(asset)
  end

  it "should return false for non-exif-encoded assets" do
    @ap.process("test/images/simple.png").must_be_nil
  end

  it "should skip processing JPG assets without EXIF headers" do
    @ap.process("test/images/simple.jpg").must_be_nil
  end

  it "should skip processing URIs that don't exist'" do
    @ap.process("test/images/zzz.jpg").must_be_nil
  end

  it "should process JPG assets with EXIF headers" do
    ea = @ap.process("test/images/Canon 20D.jpg")
    ea.wont_be_nil
    ea.reload.tags.collect { |t| t.ancestry_path.join("/") }.sort.must_equal [
      "when/2004/9/19",
        "when/seasons/autumn",
        "with/Canon/Canon EOS 20D",
        "file" + (Rails.root + "test/images").to_s
    ].sort

  end

  it "should process GPS-tagged asset" do
    ea = @ap.process("test/images/iPhone 4S.jpg")
    ea.reload.tags.collect { |t| t.ancestry_path.join("/") }.sort.must_equal [
      "when/2011/11/23",
        "when/seasons/autumn",
        "with/Apple/iPhone 4S",
        "where/Earth/North America/United States/California/San Mateo County/El Granada",
        "file" + (Rails.root + "test/images").to_s
    ].sort
  end

  it "should extract face tags from picasa" do
    ea = @ap.process("test/images/faces.jpg")
    ea.reload.tags.collect { |t| t.ancestry_path.join("/") }.sort.must_equal [
      "when/2005/11/26",
        "with/Canon/Canon EOS 20D",
        "when/seasons/autumn",
        "who/McEachen/James",
        "who/McEachen/Jamie",
        "who/McEachen/Karen",
        "who/McEachen/Matthew",
        "who/McEachen/Ruth",
        "file" + (Rails.root + "test/images").to_s
    ].sort
  end
end

describe "asset processing with image resizing" do
  it "creates resized image assets" do
    dir = "/var/tmp/testing123"
    Settings.cache_dir = dir.to_pathname
    ap = AssetProcessor.new(nil)
    ap.process("test/images/Canon 20D.jpg")

    widths, heights = [], []
    Settings.resizes.each do |ea|
      w, h = ea.split("x").to_i
      widths << w
      heights << h
    end
    widths += Settings.square_crop_sizes
    heights += Settings.square_crop_sizes

    thumbnail_root = Settings.thumbnail_root
    thumbnail_root.wont_be_nil
    Dir["#{thumbnail_root}/**/*.jpg"].each do |f|
      r = ExifMixin.exif_result(f)
      w = r[:image_width].to_i
      h = r[:image_height].to_i
      if !widths.include?(w) && !heights.include?(h)
        flunk "weird sized cache file: #{f} (#{w}x#{h})"
      end
    end
  end
end
