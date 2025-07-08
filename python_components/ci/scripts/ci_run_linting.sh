#!/usr/bin/env sh

# Define budgets (adjust these as needed)
ISORT_BUDGET=0   # Allow no isort changes
BLACK_BUDGET=0   # Allow no black changes.
FLAKE8_BUDGET=0  # Allow no flake8 errors

if [ -z "$1" ]; then
    echo "Error: Pass in a path to check, like **/*.py"
    exit 1
fi

# Run isort and capture output
isort_output="$(isort --profile black $1 --diff --check-only)"
isort_change_count=$(echo "$isort_output" | grep '^---' | wc -l) # Count diff lines

# Run black and capture any output
black_output="$(black --check --diff $1 2>&1)"
black_change_count=$(echo "$black_output" | grep '^---' | wc -l) # Count diff lines

# Run flake8 and capture output
flake8_output="$(flake8 --ignore=E501,W503,F405 $1)"
trimmed_output=$(echo "$flake8_output" | tr -d '[:space:]')

if [ -z "$trimmed_output" ]; then
  flake8_error_count=0
else
  flake8_error_count=$(echo "$flake8_output" | wc -l)
fi

# Display outputs (for debugging)
echo "Isort Output:"
echo "$isort_output"
echo "\n"
echo "Black Output:"
echo "$black_output"
echo "\n"
echo "Flake8 Output:"
echo "$flake8_output"
echo "\n"

HELP_MESSAGE="Try running python_components/ci/scripts/local_fix_linting.sh for help."

## Check isort budget
if [ "$isort_change_count" -gt "$ISORT_BUDGET" ]; then
  echo "isort changes exceeded budget ($ISORT_BUDGET). Found $isort_change_count changes."
  echo $HELP_MESSAGE
  exit 1
else
  echo "isort check passed. Found $isort_change_count changes (within budget)."
fi

# Check black budget
if [ "$black_change_count" -gt "$BLACK_BUDGET" ]; then
  echo "Black changes exceeded budget ($BLACK_BUDGET). Found $black_black_change_count changes."
  echo $HELP_MESSAGE
  exit 1
else
  echo "Black check passed. Found $black_change_count changes (within budget)."
fi

# Check flake8 budget
if [ "$flake8_error_count" -gt "$FLAKE8_BUDGET" ]; then
  echo "Flake8 errors exceeded budget ($FLAKE8_BUDGET). Found $flake8_error_count errors."
  echo $HELP_MESSAGE
  exit 1
else
  echo "Flake8 check passed. Found $flake8_error_count errors (within budget)."
fi

exit 0