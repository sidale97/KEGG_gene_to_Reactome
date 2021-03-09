#!/bin/sh
load_missing_new_genes_thread_query='../files/cypher_queries/load_missing_new_genes'
load_missing_new_cross_references_thread_query='../files/cypher_queries/load_missing_new_cross_references' # _verbose'

load_missing_new_genes_thread () {
  split_file="$1" ;
  file_to_load="$split_file".tmp
  cat "$split_file" | while IFS="$(printf '\t')" read hsa rest ;
  do
    echo "$rest" | cut -d '|' -f 2 | cut -d ';' -f 1 | sed 's/(RefSeq)//' | tr ',' '\n' | tr -d ' ' | while read gene_name ;
    do echo "$(echo $hsa | cut -d : -f 2)","$gene_name" ;
    done ;
  done   >"$file_to_load" ;

  parent_directory_name="$(basename "$( realpath .. )" )"
  echo HHHHHHHHHHHHHHHHHHHHHHH parent_directory_name: "$parent_directory_name"

  file_to_load_path="$parent_directory_name"/run/"$file_to_load"
  echo $file_to_load_path FILE TO LOAD PATH
  $to_cypher_shell_with_login -P "file => '$file_to_load_path'" <"$load_missing_new_genes_thread_query" ;

  cypher_shell_exit_status="$?"
#  rm "$file_to_load" ; optional , since $splitting_directory gets deleted anyway
  return "$cypher_shell_exit_status" ;
}


load_missing_new_cross_references_thread () {
  split_file="$1" ;
  file_to_load="$split_file"'.tmp' ;
  cat "$split_file" | while read gene_name ;
  do
      # translate towards hsa
      hsa_identifier="$(echo $gene_name | cut -d : -f 2)"
      cat "$cross_references_translation_file" | grep '^hsa' | cut -d , -f 4 | while read reactome_hsa_prefix
      do echo "hsa,$hsa_identifier,$reactome_hsa_prefix,$hsa_identifier,[KEGG genes in Reactome]hsa:$hsa_identifier" ;
    done ;

      # translate the actual identifier
      gene_file="$cross_references_directory_diff"/"$gene_name" ;
      cat "$gene_file" | translate_cross_reference ;
   done | sort | uniq >"$file_to_load" ;

    parent_directory_name="$(basename "$( realpath .. )" )" ;
    file_to_load_path="$parent_directory_name"/run/"$file_to_load" ;
    $to_cypher_shell_with_login -P "file => '$file_to_load_path'" <"$load_missing_new_cross_references_thread_query" ;

   cypher_shell_exit_status="$?"
#    rm "$output_file" ; optional, since $splitting_directory gets deleted anyway
   return "$cypher_shell_exit_status" ;
}

translate_cross_reference () {
  while IFS="$(printf '\t')"  read hsa other link_type ;
  do
    hsa_prefix="$( echo "$hsa" | cut -d : -f 1 )"
    other_prefix="$( echo "$other" | cut -d : -f 1 )"
    hsa_identifier="$( echo "$hsa" | cut -d : -f 2 )"
    other_identifier="$( echo "$other" | cut -d : -f 2 )"

    cat "$cross_references_translation_file" | tail +2 | grep -v '^hsa,' | grep -v ',null$' | grep '^'"$other_prefix" | cut -d ',' -f 4 | while read other_prefix_translated ;
    do echo "$hsa_prefix,$hsa_identifier,$other_prefix_translated,$other_identifier,$link_type"
    done ;
## slower but clearer way to parse the translation file
#    while IFS=, read db_prefix_kegg _  _ db_prefix_reactome ;
#    do
#      if test "$db_prefix_kegg" = 'hsa' ; then continue ; fi ;
#      if test "$db_prefix_reactome" = 'null' ; then continue ; fi ;
#      if test "$other_prefix" = "$db_prefix_kegg" ;
#      then
#        other_prefix_translated="$db_prefix_reactome";
#        echo "$hsa_prefix,$hsa_identifier,$other_prefix_translated,$other_identifier" ;
#      fi ;
#    done ;
  done ;
}

function_to_call="$1"
file_to_work_on="$2"
eval "$function_to_call" "$file_to_work_on" ;
