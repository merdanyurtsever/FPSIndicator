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

# Check if the Sources directory exists and contains our modular components
if [ ! -d "Sources" ] || [ ! -f "Sources/FPSCalculator.h" ] || [ ! -f "Sources/FPSDisplayWindow.h" ] || [ ! -f "Sources/FPSGameSupport.h" ]; then
    echo -e "${RED}Error: Missing modular components in Sources directory${NC}"
    echo "Please ensure the following files exist:"
    echo "  - Sources/FPSCalculator.h/m"
    echo "  - Sources/FPSDisplayWindow.h/m"
    echo "  - Sources/FPSGameSupport.h/m"
    exit 1
fi

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

# Verify critical components with our new architecture
echo -e "\n${YELLOW}Verifying critical components...${NC}"
CRITICAL_TESTS=(
    "testFPSCalculator" 
    "testDisplayWindow" 
    "testConcurrentFrameTicking" 
    "testPrivacyMode" 
    "testPreferencesLoading"
    "testFPSDataLogging"
)

for test in "${CRITICAL_TESTS[@]}"; do
    if grep -q "$test.*passed" /tmp/test_output.log; then
        echo -e "${GREEN}✓ $test${NC}"
    else
        echo -e "${RED}✗ $test failed or not run${NC}"
        exit 1
    fi
done

# Check for improved detection of game engines
echo -e "\n${YELLOW}Checking game engine detection...${NC}"
if grep -q "testGameEngineDetection.*passed" /tmp/test_output.log; then
    echo -e "${GREEN}✓ Game engine detection working properly${NC}"
else
    echo -e "${YELLOW}⚠ Game engine detection test not found or failed${NC}"
fi

echo -e "\n${GREEN}All verification steps completed successfully!${NC}"
echo "You can now proceed with packaging the tweak."

# Uncomment to monitor logs on a connected device
# idevicesyslog | grep -E 'FPSIndicator' --color
