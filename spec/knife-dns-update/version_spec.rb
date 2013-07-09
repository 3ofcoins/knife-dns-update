require 'spec_helper'

# A smoke test spec to make sure tests actually work

module KnifeDnsUpdate
  describe VERSION do
    it 'is equal to itself' do
      expect { VERSION == KnifeDnsUpdate::VERSION }
    end
  end
end
