require 'minitest/autorun'
require 'date'
require 'rack/test'
require 'sinatra/base'

module DotMatrix

  UnknownAttributeError = Class.new ArgumentError

  ##########################################################################

  class Repository
    
    def initialize
      @repos = { Consultant => ConsultantRepository.new }
    end

    def for(klass)
      @repos.fetch klass
    end
  end

  class ConsultantRepository

    def initialize
      @objects = []
      @id = -1
    end

    def count
      @objects.count
    end

    def first
      @objects.first
    end

    def find(id)
      @objects[id]
    end

    def all
      @objects
    end
    
    def save obj
      @id += 1
      obj.id = @id
      @objects << obj
    end
  end

  ##########################################################################

  class Consultant

    attr_accessor :id, :name
   
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

  ##########################################################################

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

  class AssignmentForm

    attr_accessor :starts_at, :ends_at
    attr_accessor :project

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

  ##########################################################################

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

  class AssignConsultant

    def initialize consultant:, form:, repo:
      @form = form
      @repo = repo
    end

    def run!
    end
  end

  ##########################################################################

  class Server < Sinatra::Base
    enable :inline_templates

    class ParameterMissingError < StandardError
      def initialize(key)
        @key = key
      end

      def to_s
        %Q{Request did not provide "#{@key}"}
      end
    end

    def initialize(*args)
      super(*args)
      @repo = Repository.new
    end

    get "/" do
      "<h1>The (Dot-)Matrix</h1>"
    end

    get "/consultants" do
      @consultants = @repo.for(Consultant).all
      haml :consultants
    end

    get "/consultant" do
      haml :consultant_form
    end

    get "/consultant/:id" do |id|
      id = id.to_i
      consultant = @repo.for(Consultant).find(id)
      "<h2>#{consultant.name}</h2>"
    end

    post "/consultant" do
      form = ConsultantForm.new name: extract!(:name)
      use_case = CreateConsultant.new form, @repo.for(Consultant)
      consultant = use_case.run!
      redirect to("/consultant/#{consultant.id}")
    end

    helpers do
      def extract!(key)
        value = params.fetch(key.to_s) do
          raise ParameterMissingError, key
        end
        value
      end
    end

  end

  ##########################################################################

  class ServerTest < MiniTest::Unit::TestCase
    include Rack::Test::Methods

    def app
      Server
    end

    def test_returns_a_200_for_root
      get '/'
      assert_equal 200, last_response.status
    end

    def test_create_new_consultant
      post '/consultant', { name: "Foo Bar" }
      follow_redirect!
      assert_equal 200, last_response.status
      assert_match /Foo Bar/, last_response.body
    end

    def test_assign_a_project_to_a_consultant
      get '/consultants'
      assert_equal 200, last_response.status
    end

  end


  ##########################################################################

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
  
  class AssignConsultantTest < MiniTest::Unit::TestCase

    def setup
      @consultant = Consultant.new name: "Foo"
      r = Repository.new
      @repo = r.for(Consultant)
    end

    def test_assigning_a_consultant_to_a_project
      form = AssignmentForm.new starts_at: Date.new(2014, 1, 1), ends_at: Date.new(2014, 2, 1), project: "Bar"
      use_case = AssignConsultant.new consultant: @consultant, form: form, repo: nil
      consultant = use_case.run!
      
      refute_nil consultant
      assert_equal 1, consultant.assignments.count
    end
  end
end

__END__

@@consultants
%table
  - @consultants.each do |c|
    %tr
      %td= c.name

@@consultant_form
%form(method="POST" action="/consultant")
  -# FIXME use url helper
  %dl
    %dt
      Name
    %dd
      %input(name="name")
  %input(type="submit")
