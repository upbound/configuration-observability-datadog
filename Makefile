# Project Setup
PROJECT_NAME := configuration-observability-datadog
PROJECT_REPO := github.com/upbound/$(PROJECT_NAME)

# NOTE(hasheddan): the platform is insignificant here as Configuration package
# images are not architecture-specific. We constrain to one platform to avoid
# needlessly pushing a multi-arch image.
PLATFORMS ?= linux_amd64
-include build/makelib/common.mk

# ====================================================================================
# Setup Kubernetes tools

UP_VERSION = v0.18.0
UP_CHANNEL = stable
UPTEST_VERSION = v0.2.1

-include build/makelib/k8s_tools.mk

# ====================================================================================
# Setup Images
# Due to the way that the shared build logic works, images should
# all be in folders at the same level (no additional levels of nesting).

REGISTRY_ORGS = xpkg.upbound.io/crossplane-contrib
IMAGES = x-metrics
-include build/makelib/imagelight.mk

# ====================================================================================
# Setup XPKG

# NOTE(jastang): Configurations deployed in Upbound do not currently follow
# certain conventions such as the default examples root or package directory.
XPKG_DIR = $(shell pwd)
XPKG_EXAMPLES_DIR = .up/examples
XPKG_IGNORE = .github/workflows/ci.yaml,.github/workflows/tag.yml,.github/workflows/e2e.yaml,init/*.yaml,.up/examples/upbound/*.yaml,.work/uptest-datasource.yaml,.up/config/*/*,.up/examples/datadog.yaml,cluster/*/*/*

XPKG_REG_ORGS ?= xpkg.upbound.io/upbound
# NOTE(hasheddan): skip promoting on xpkg.upbound.io as channel tags are
# inferred.
XPKG_REG_ORGS_NO_PROMOTE ?= xpkg.upbound.io/upbound
XPKGS = $(PROJECT_NAME)
-include build/makelib/xpkg.mk

CROSSPLANE_NAMESPACE = upbound-system
CROSSPLANE_ARGS = "--debug"
-include build/makelib/local.xpkg.mk
-include build/makelib/controlplane.mk

# ====================================================================================
# Targets

# run `make help` to see the targets and options

# We want submodules to be set up the first time `make` is run.
# We manage the build/ folder and its Makefiles as a submodule.
# The first time `make` is run, the includes of build/*.mk files will
# all fail, and this target will be run. The next time, the default as defined
# by the includes will be run instead.
fallthrough: submodules
	@echo Initial setup complete. Running make again . . .
	@make

# Update the submodules, such as the common build scripts.
submodules:
	@git submodule sync
	@git submodule update --init --recursive

# We must ensure up is installed in tool cache prior to build as including the k8s_tools machinery prior to the xpkg
# machinery sets UP to point to tool cache.
build.init: $(UP)

# ====================================================================================
# End to End Testing

# This target requires the following environment variables to be set:
# - UPTEST_CLOUD_CREDENTIALS, cloud credentials for the provider being tested, e.g. export UPTEST_CLOUD_CREDENTIALS=$(cat ~/.aws/credentials)
# - To ensure the proper functioning of the end-to-end test resource pre-deletion hook, it is crucial to arrange your resources appropriately. 
#   You can check the basic implementation here: https://github.com/upbound/uptest/blob/main/internal/templates/01-delete.yaml.tmpl.
uptest: $(UPTEST) $(KUBECTL) $(KUTTL)
	@$(INFO) running automated tests
	@KUBECTL=$(KUBECTL) KUTTL=$(KUTTL) $(UPTEST) e2e .up/examples/datadog.yaml --setup-script=test/setup.sh --default-timeout=2400 || $(FAIL)
	@$(OK) running automated tests

# This target requires the following environment variables to be set:
# - UPTEST_CLOUD_CREDENTIALS, cloud credentials for the provider being tested, e.g. export UPTEST_CLOUD_CREDENTIALS=$(cat ~/.aws/credentials)
e2e: build controlplane.up local.xpkg.deploy.configuration.$(PROJECT_NAME) uptest

.PHONY: uptest e2e
