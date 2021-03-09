==== "KEGG Gene to Reactome" tool ====

 This repository  contains a Unix Shell tool which automatically loads KEGG Genes entries into Reactome's graph database via Neo4j, and links them to any Reactome entry for which it found a cross reference (or a concatenation of cross references).

The tool is open source and available for free download on GitHub, at the following link: https://github.com/sidale97/KEGG_gene_to_Reactome

==== Tool usage ====

The tool is entirely contained in the folder named "tool", which is the folder the file you are reading is stored in.

The tool folder  must be placed in a particular sub-directory of the Neo4j instance Reactome is hosted by: it must be placed directly inside Neo4j’s "import" folder.

The "run" directory inside the tool folder contains a file named "main.sh".

In order to run the tool, the user must invoke "main.sh" passing the desired subcommand and options as arguments.

If the tool is "sourced" by a Unix shell, then such shell's working directory must be the "run" subfolder contained in the tool folder, otherwise the tool won't function and it will refuse to start.

====  Available commands  ====

- "download new genes": downloads a brand new list of human genes from KEGG.
- "download new cross references": downloads a brand new list of cross references, for each new gene previously downloaded.
- "count missing new genes": counts how many new genes weren’t previously loaded into Reactome.
 -"count missing new cross references": computes new available cross references and counts how many new cross references weren’t previously loaded into Reactome.
- "load missing new genes": loads into Reactome the genes which still weren’t and links them via gene name.
- "load missing new cross references": loads into Reactome the computed cross references which still weren’t,.
- "delete loaded genes and cross references": deletes all genes and cros references previously loaded into Reactome .
- "delete cache": deletes the program cache.  
- "login username password": sets the credentials to login into Neo4j to username username and password password .
- "logout": unsets the Neo4j login credentials.
- "prepare neo4j": instructs Neo4j to create indexes and constraints.
- "auto username password": executes all non-delete commands: downloads, counts and loads new genes and cross references.

==== Available options ====

-j N : use N parallel processes, or as many as the number of cores on your computer if N=0.
-f : never prompt the user. Answers "yes" to any given question, e.g. the overriding of data already present in cache.
