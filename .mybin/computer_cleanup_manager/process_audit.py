import csv

filepath = 'repos_analysis.txt'

results = []

nbchanges = "unknown"  
nbuntracked = "unknown"
folder_name = "unknown"
remote_url = "unknown"


with open(filepath) as fp:
   line = fp.readline()
   cnt = 1
   
   while line:
       line = line.strip()
       print("Line {}: '{}'".format(cnt, line.strip()))

      
       if line.startswith("dev"):
         folder_name = line

       if line.startswith("Nb untracked files ="):
         nbuntracked = line.replace("Nb untracked files =", "").strip()

       if line.startswith("Nb peding changes ="):
         nbchanges = line.replace("Nb peding changes =", "").strip()

       if line.startswith("Remote Url ="):
         remote_url = line.replace("Remote Url =", "").strip()

       if line.startswith("======="):
         print("End of a repo. saving data ...")
         results.append([folder_name, remote_url, nbchanges, nbuntracked])
         print("Done")

         nbchanges = "unknown"  
         nbuntracked = "unknown"
         folder_name = "unknown"
         remote_url = "unknown"


       line = fp.readline()
       cnt += 1


print("writing to csv")

def write_array_to_csv(array, filename):
    """
    Writes an array to a CSV file.
 
    Parameters:
    - array: list
        The array to be written to the CSV file.
    - filename: str
        The name of the CSV file to be created.
 
    Returns:
    - None
 
    Raises:
    - TypeError:
        If the 'array' parameter is not a list.
    """
 
    # Checking if the 'array' parameter is a list
    if not isinstance(array, list):
        raise TypeError("The 'array' parameter should be a list.")
 
    # Opening the CSV file in write mode
    with open(filename, 'w', newline='') as file:
        # Creating a CSV writer object
        writer = csv.writer(file)
 
        # Writing each element of the array as a row in the CSV file
        for row in array:
            writer.writerow(row)
 
# Example usage:
array = results #[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
filename = 'output.csv'
 
try:
    write_array_to_csv(array, filename)
    print(f"The array has been successfully written to the file '{filename}'.")
except TypeError as e:
    print(f"Error: {e}")
