#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Running FPSIndicator test suite...${NC}\n"

# Check if OCMock is installed
if [ ! -f "$THEOS/lib/libOCMock.dylib" ]; then
    echo -e "${RED}Error: OCMock framework not found${NC}"
    echo "Please install OCMock first:"
    echo "git clone https://github.com/erikdoe/ocmock.git"
    echo "cd ocmock && ./BuildRelease"
    echo "cp -r Build/Release/OCMock.framework $THEOS/lib/"
    exit 1
fi

# Clean previous builds
make clean >/dev/null 2>&1

# Run the tests
echo "Building and running tests..."
if make test 2>&1 | tee /tmp/test_output.log; then
    echo -e "\n${GREEN}All tests passed successfully!${NC}"
else
    echo -e "\n${RED}Some tests failed. Check the output above for details.${NC}"
    echo -e "\nFull test log available at /tmp/test_output.log"
    exit 1
fi

# Check for memory leaks
echo -e "\n${YELLOW}Checking for memory leaks...${NC}"
if grep -q "leaked:" /tmp/test_output.log; then
    echo -e "${RED}Memory leaks detected! Check the test output for details.${NC}"
    exit 1
else
    echo -e "${GREEN}No memory leaks detected.${NC}"
fi

# Verify critical components
echo -e "\n${YELLOW}Verifying critical components...${NC}"
CRITICAL_TESTS=("testFrameTickAccuracy" "testWindowInitialization" "testThreadSafety")
for test in "${CRITICAL_TESTS[@]}"; do
    if grep -q "$test.*passed" /tmp/test_output.log; then
        echo -e "${GREEN}✓ $test${NC}"
    else
        echo -e "${RED}✗ $test failed or not run${NC}"
        exit 1
    fi
done

echo -e "\n${GREEN}All verification steps completed successfully!${NC}"
echo "You can now proceed with packaging the tweak."

idevicesyslog | grep -E 'FPSIndicator' --color
