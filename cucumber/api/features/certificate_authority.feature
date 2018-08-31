Feature: Conjur signs certificates using a configured CA

  Background:
    Given I am the super-user
    And I successfully PUT "/policies/cucumber/policy/root" with body:
    """
    - !policy
      id: conjur/kitchen/ca
      body:
        - !variable private-key
        - !variable cert-chain

        - !webservice
          annotations:
            ca/private-key: conjur/kitchen/ca/private-key
            ca/certificate-chain: conjur/kitchen/ca/cert-chain
            ca/max_ttl: P1Y

        - !group clients

        - !permit
          role: !group clients
          privilege: [ sign ]
          resource: !webservice

    - !host bacon
    - !host toast
    - !user alice

    - !grant
      role: !group conjur/kitchen/ca/clients
      member: !host bacon
    """
    And I have an intermediate CA
    And I add the intermediate CA private key to the resource "cucumber:variable:conjur/kitchen/ca/private-key"
    And I add the intermediate CA cert chain to the resource "cucumber:variable:conjur/kitchen/ca/cert-chain"

  Scenario: A non-existent ca returns a 404
    When I POST "/ca/cucumber/living-room/sign"
    Then the HTTP response status code is 404

  Scenario: A login that isn't a host returns a 403
    When I POST "/ca/cucumber/kitchen/sign"
    Then the HTTP response status code is 403

  Scenario: The service returns 403 Forbidden if the host doesn't have sign privileges
    Given I login as "cucumber:host:toast"
    When I send a CSR for "toast" to the "kitchen" CA with a ttl of "P6M" and CN of "toast"
    Then the HTTP response status code is 403

  Scenario: The service returns 403 Forbidden if the CSR CN doesn't match the host
    Given I login as "cucumber:host:bacon"
    When I send a CSR for "bacon" to the "kitchen" CA with a ttl of "P6M" and CN of "toast"
    Then the HTTP response status code is 403

  Scenario: I can sign a valid CSR with a configured Conjur CA
    Given I login as "cucumber:host:bacon"
    When I send a CSR for "bacon" to the "kitchen" CA with a ttl of "P6M" and CN of "bacon"
    Then the HTTP response status code is 201
    And the HTTP response content type is "application/json"
    And the resulting json certificate is valid according to the intermediate CA

  Scenario: I can receive the result directly as a PEM formatted certificate
    Given I login as "cucumber:host:bacon"
    And I set the "Accept" header to "application/x-pem-file" 
    When I send a CSR for "bacon" to the "kitchen" CA with a ttl of "P6M" and CN of "bacon"
    Then the HTTP response status code is 201
    And the HTTP response content type is "application/x-pem-file"
    And the resulting pem certificate is valid according to the intermediate CA
