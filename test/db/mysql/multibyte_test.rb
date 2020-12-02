# -*- encoding : utf-8 -*-
require 'jdbc_common'
require 'db/mysql'

class MySQLMultibyteTest < Test::Unit::TestCase
  include MultibyteTestMethods
end

class MySQLNonUTF8EncodingTest < Test::Unit::TestCase
  include NonUTF8EncodingMethods

  def test_nonutf8_encoding_in_entry
    prague_district = 'hradčany'
    new_entry = Entry.create :title => prague_district
    new_entry.reload
    # NOTE: MRI gets Latin2 right? on MySQL
    if defined? JRUBY_VERSION
      # NOTE: hopefully it's not an issue that we do not force Latin-2
      assert_equal prague_district, new_entry.title
    else
      if ''.respond_to? :force_encoding
        assert_equal "hrad\xE8any".force_encoding('ISO-8859-2'), new_entry.title
      else
        assert_equal prague_district, new_entry.title
      end
    end
  end

end
