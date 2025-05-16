import os
import pandas as pd
import glob

def load_georgia_csvs(directory='.'):
    """
    Load all CSV files ending with '_georgia.csv' in the specified directory.

    Args:
        directory: The directory path to search for CSV files (default: current directory)

    Returns:
        A dictionary where keys are filenames and values are pandas DataFrames
    """
    # Create the pattern to match files ending with _georgia.csv
    pattern = os.path.join(directory, '*_georgia.csv')

    # Find all matching files
    georgia_files = glob.glob(pattern)

    # Dictionary to store the loaded DataFrames
    dataframes = {}

    # Load each file into a DataFrame
    for file_path in georgia_files:
        # Extract just the filename for the dictionary key
        filename = os.path.basename(file_path)

        # Read the CSV into a pandas DataFrame
        try:
            df = pd.read_csv(file_path)
            dataframes[filename] = df
            print(f"Loaded {filename} with {len(df)} rows and {len(df.columns)} columns")
        except Exception as e:
            print(f"Error loading {filename}: {e}")

    print(f"Loaded {len(dataframes)} Georgia CSV files in total\n")
    return dataframes

if __name__ == "__main__":
    # Load all files from the current directory
    recent_georgia_data = load_georgia_csvs()
    more_georgia_data = load_georgia_csvs('csvs/')
    georgia_data = recent_georgia_data | more_georgia_data

    number_of_pdfs = 0
    for key, df in georgia_data.items():
        number_of_pdfs += len(df)
    print(f"Total PDFs from Georgia: {number_of_pdfs}")

    # If you have files in a different directory, specify the path
    # georgia_data = load_georgia_csvs('/path/to/your/csv/directory')

    # Now you can access each DataFrame by its filename
    # For example, if you have 'population_georgia.csv':
    # population_df = georgia_data['population_georgia.csv']