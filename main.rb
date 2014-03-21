require 'minitest/autorun'

module DotMatrix

  class ConsultantRepository

    def initialize
      @objects = []
    end

    def count
      @objects.count
    end

    def first
      @objects.first
    end

    def save obj
      @objects << obj
    end
  end

  class Consultant
    attr_accessor :name
   
    def initialize values={}
      values.each_pair do |key, value|
        if respond_to? "#{key}="
          send "#{key}=", value
        else
          raise UnknownAttributeError, key
        end
      end
    end
  end

  class ConsultantForm
    attr_accessor :name

    def initialize values={}
      values.each_pair do |key, value|
        if respond_to? "#{key}="
          send "#{key}=", value
        else
          raise UnknownAttributeError, key
        end
      end
    end

    def valid?
      true
    end

  end

  class Repository
    
    def initialize
      @repos = { Consultant => ConsultantRepository.new }
    end

    def for(klass)
      @repos.fetch klass
    end
  end

  class CreateConsultant

    def initialize form, repo
      @form = form
      @repo = repo
    end

    def run!
      raise ValidationError, @form.errors unless @form.valid?
      obj = Consultant.new name: @form.name
      @repo.save obj
      obj
    end
  end

  class CreateConsultantTest < MiniTest::Unit::TestCase

    def setup
      r = Repository.new
      @repo = r.for(Consultant)
    end

    def test_saving_a_new_consultant
      form = ConsultantForm.new name: "Foo"
      use_case = CreateConsultant.new form, @repo
      consultant = use_case.run!

      refute_nil consultant
      assert_equal 1, @repo.count
      assert_equal consultant, @repo.first
    end
  
  end
end

