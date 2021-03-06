require 'spec_helper'

describe Saml::ComplexTypes::RequestAbstractType do
  let(:request_abstract_type) { FactoryGirl.build(:request_abstract_type_dummy) }

  describe "Required fields" do
    [:_id, :version, :issue_instant].each do |field|
      it "should have the #{field} field" do
        request_abstract_type.should respond_to(field)
      end

      it "should check the presence of #{field}" do
        request_abstract_type.send("#{field}=", nil)
        request_abstract_type.should_not be_valid
      end
    end
  end

  describe "Optional fields" do
    [:destination, :issuer, :signature, :extensions, :consent].each do |field|
      it "should have the #{field} field" do
        request_abstract_type.should respond_to(field)
      end

      it "should allow #{field} to blank" do
        request_abstract_type.send("#{field}=", nil)
        request_abstract_type.should be_valid
        request_abstract_type.send("#{field}=", "")
        request_abstract_type.should be_valid
      end
    end
  end

  describe ".parse" do
    let(:request_abstract_type_xml) { File.read(File.join('spec', 'fixtures', 'authn_request.xml')) }
    let(:request_abstract_type) { Saml::AuthnRequest.parse(request_abstract_type_xml) }

    it "should parse the id" do
      request_abstract_type._id.should == "_c392374de287c092408062878fbc23edf9bb3508"
    end

    it "should parse the version" do
      request_abstract_type.version.should == "2.0"
    end

    it "should parse the issuer" do
      request_abstract_type.issuer.should == "https://sp.example.com"
    end

    it "should parse issue_instant" do
      request_abstract_type.issue_instant.should == Time.parse("2011-08-31T08:30:56+02:00")
    end

    it "should set the from_xml to true" do
      request_abstract_type.from_xml?.should == true
    end

    it "should parse the destination" do
      request_abstract_type.destination.should == 'http://test.url/sso'
    end
  end

  describe "#add_signature" do
    it "adds a signature element to the request" do
      request_abstract_type.add_signature
      parsed_request_abstract_type = RequestAbstractTypeDummy.parse(request_abstract_type.to_xml, single: true)
      parsed_request_abstract_type.signature.should be_a(Saml::Elements::Signature)
    end
  end

  describe "#to_soap" do
    it "wraps the xml in a soap envelope" do
      Nokogiri::XML::Document.parse(request_abstract_type.to_soap).root.name.should == "Envelope"
    end

    it "adds wsa header if options are given" do
      soap = request_abstract_type.to_soap(
          header: {
              wsa_message_id: 'id',
              wsa_action:     'some_action',
              wsa_to:         'to',
              wsa_address:    'address'
          }
      )
      xml = Hash.from_xml(soap)
      xml["Envelope"]["Header"].should eq(
                                           "MessageID" => "id",
                                           "To"        => "to",
                                           "Action"    => "some_action",
                                           "ReplyTo"   => { "Address" => "address" },
                                           'xmlns:wsa' => 'http://schemas.xmlsoap.org/ws/2004/08/addressing'
                                       )
    end
  end

  describe "IssueInstant" do
    it "should not be valid if the issue instant is too old" do
      request_abstract_type.issue_instant = Time.now - Saml::Config.max_issue_instant_offset.minutes
      request_abstract_type.should have(1).errors_on(:issue_instant)
    end

    it "should not raise error when issue_instant is blank" do
      request_abstract_type.issue_instant = nil
      expect {
        request_abstract_type.to_xml
      }.not_to raise_error
    end
  end

  describe "Version" do
    it "should not be valid if the version is not allowed" do
      request_abstract_type.version = "invalid"
      request_abstract_type.should have(1).errors_on(:version)
    end
  end

  describe "default values" do
    it "should generate an ID" do
      Saml::AuthnRequest.new._id.should_not be_blank
    end
  end

  describe "Destination" do
    it "should not be valid if the actual destination does not contain the request destination" do
      request_abstract_type.actual_destination = 'http://failed.url'
      request_abstract_type.should have(1).errors_on(:destination)
    end
  end
end
