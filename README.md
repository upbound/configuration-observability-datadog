# platform-ref-observability-datadog
Platform Reference to Set Up a Datadog agent for Crossplane 
and Provider Observability.

## Usage
Run `make e2e` to exercise end to end tests for the observability
integrations. It requires a DATADOG_API_KEY and DATADOG_APP_KEY. 
You may assign your API key also to the DATADOG_APP_KEY, if you
do not have a dedicated DATADOG_API_KEY.

The cluster will stick around and you can run `kubectl apply -f
examples/datadog.yaml` to install the agent and its dependencies.

The `_output` directory includes readily usable configuration packages
after `make build` has been run.

## Community
Feel free to join the [SIG Observability Slack Channel](https://crossplane.slack.com/archives/C061GNH3LA0)
to participate in the Crossplane observability journey.
