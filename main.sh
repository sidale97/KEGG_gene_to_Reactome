#!/bin/sh
#comments beginning with "CHECK" signal things which have to be proven bug free
# known issues : sometimes, at start, $splitting_directory is already present and doesnt get removed by the journaling system

main() {
chmod 777 ../* -R
if test $# -eq 0 ; then cat ../files/commands_list.txt ; return 1 ; fi

number_of_parallel_jobs=1
option_f_set=''
while true ;
do
  begins_with_dash="$(echo "$1" | grep -- "-.*")";
  if ! test "$begins_with_dash" ; then break ; fi ;
  case "$1" in
  '-f')
    option_f_set=_ ;
    shift ;
  ;;
  '-j')
    if test $# -lt 2 ; then echo "$0: ERROR: missing -j option argument" ; fi ;
    n="$2"
    if test "$n" -eq 0 ; #numeric , not string, equivalency
    then number_of_parallel_jobs="100%" ;
    fi;
    is_natural_number="$(echo "$n" | grep '^[1-9][0-9]*$' )" ;
    if test "$is_natural_number"  ;
    then number_of_parallel_jobs="$n" ;
     else
       echo 'number of jobs must be a natural number, got "'"$n"'".' ;
       return 1 ;
     fi ;
    shift 2 ;
  ;;
  *)
    echo "$0: ERROR: option '$1' not recognized ; $(cat "$commands_list_file")"
  return 1 ;
  ;;
  esac ;
done ;

  if ! set_environment ; then return 1 ; fi ;

  if ! handle_command "$@" ; then return 1 ; fi ;

  }

set_environment () {

if ! check_installed_programs ; then return 1 ; fi ;

commands_list_file='../files/commands_list.txt'

error_command_not_recognized="$0: ERROR: command not recognized.
$(cat "$commands_list_file")

" ;

  cross_references_translation_file="../files/prefixes_translated_by_a_human.csv"

  cache_directory='../cache'


  genes_list_file="$cache_directory"/'genes_list'
  cross_references_directory="$cache_directory"/'cross_references'

  genes_list_file_new="$genes_list_file""_new"
  cross_references_directory_new="$cross_references_directory""_new"

  genes_list_file_diff="$genes_list_file""_diff"
  cross_references_directory_diff="$cross_references_directory""_diff"

  further_cross_references_directory="$cache_directory/further_cross_references"

  genes_list_link="http://rest.genome.jp/list/hsa"
  cross_references_link="http://rest.genome.jp/link/"
  uniprot_cross_references_link='ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/idmapping/by_organism/HUMAN_9606_idmapping.dat.gz'
  ncbi_gene_to_ensembl='ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene2ensembl.gz'
  ncbi_gene_to_refseq='ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene2refseq.gz'
  ncbi_refseq_uniprot_collab='ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene_refseq_uniprotkb_collab.gz'

for x in 'ena' 'uniprot' 'entrez' 'refseq' ;
do eval "ensembl_to_${x}=ftp.ensembl.org/pub/current_tsv/homo_sapiens/Homo_sapiens.GRCh38.103.${x}.tsv.gz"
done ;




  journal='.journal'
  wget_log='.wget_log'
  joblog=".joblog"
  genes_per_batch=10 ; # the average gene has 68 cross references, this way each neo4j load CSV has 680 lines to handle
  splitting_directory='../splitted'
  parallel_fifo='.parallel.fifo'
  if_exists_remove "$parallel_fifo" ;

  if ! test -e "$cache_directory" ; then mkdir "$cache_directory" ; fi;
  if ! test -e "$genes_list_file" ; then touch "$genes_list_file" ; fi ;
  if ! test -e "$cross_references_directory" ; then mkdir "$cross_references_directory" ; fi ;
   if ! test -e "$journal" ; then touch "$journal" ; fi ;

  if ! handle_journal ;
  then return 1 ;
  fi ;

  to_cypher_shell_with_login='/bin/sh .to_cypher.sh'
  export to_cypher_shell_with_login ;


  export cache_directory cross_references_directory_new #for cross_references_translation_thread.sh
  export cross_references_directory_diff
  export cross_references_translation_file
}

handle_command () {
case "$@" in
       'download new genes')
        download_new_genes  ;
        return "$?"
     ;;
    'download new cross references'*)
       download_new_cross_references ;
       return "$?" ;
     ;;
    'count missing new genes')
      count_missing_new_genes  ;
      return "$?" ;
    ;;
    'count missing new cross references')
        count_missing_new_cross_references ;
        return "$?" ;
    ;;
    'load missing new genes')
       if ! check_logged_in ; then return 1 ; fi ;
      load_missing_new_genes  ;
      return "$?" ;
    ;;
    'load missing new cross references')
      if ! check_logged_in ; then return 1 ; fi ;
      load_missing_new_cross_references ;
      return "$?" ;
    ;;
    'delete loaded genes and cross references')
        if ! check_logged_in ; then return 1 ; fi ;
	delete_loaded_genes_and_cross_references ;
	echo "$?" ;
    ;;
    'delete cache')
      if ! check_logged_in ; then return 1 ; fi ;
      return 0 ;
   ;;
   'login'*)
     if ! login "$@" ;
     then return 1 ;
     fi ;
     return 0 ;
     ;;
     'logout')
       if ! check_logged_in ; then return 1 ; fi ;
       if_exists_remove "$to_cypher_shell_with_login" ;
       echo logged out. ;
     ;;
     'prepare neo4j')
         if ! check_logged_in ; then return 1 ; fi ;
         prepare_neo4j ;
         return "$?"
     ;;
     'auto')
       if ! check_logged_in ; then return 1 ; fi ;
       auto ;
       return "$?" ;
    ;;
    *)
      echo "$error_command_not_recognized" ;
      return 1 ;
    ;;
    esac
}

check_installed_programs () {
for program in "parallel" "gzip" "wget" ;
  do
    if ! command -v "$program" 1>/dev/null 2>&1 ;
    then
      echo "$0: ERROR: program '$program' is not installed. Please install it and retry.";
      return 1 ;
    fi ;
  done ;
}

handle_journal () {

  record="$(cat "$journal")" 
    case "$record" in
    "download new genes")
      echo  "$0: $LINENO: WARNING: The last execution halted while performing \"$record\" and the progress was lost. Continue?" ;
      if ! ask_for_confirmation ; then return 1 ; fi ;
      if_exists_remove "$genes_list_file_new" ;
    ;;
    "download new cross references")
      echo  "$0: $LINENO: WARNING: The last execution halted while performing \"$record\" and the progress was lost. Continue?" ;
      if ! ask_for_confirmation ; then return 1 ; fi ;
      if_exists_remove "$cross_references_directory_new" ; 
     ;;
    'load missing new genes'|'load missing new cross references')
      echo "WARNING: The last execution halted while performing \"$record\". I couldn't rollback the changes, so Neo4j was only partially updated. You'll have to run \"$record\" again (with the same \"new\" data) to complete the operation." ;
      echo 'continue?' ;
      if ! ask_for_confirmation ; then return 1 ; fi ;
      if_exists_remove "$splitting_directory" ;
    ;;
    'count missing new cross references')
      echo  "$0: $LINENO: WARNING: The last execution halted while performing \"$record\" and the progress was lost. Continue?" ;
      if ! ask_for_confirmation ; then return 1 ; fi ;
      if_exists_remove "$cross_references_directory_diff"
     ;; 
    '') return 0 ; #journal is empty, nothing to do.
    ;;
    *)
      echo 'ERROR: journal parsing failed.' ; 
      return 1 ;
    ;;
    esac ;

  echo '' >"$journal" ;
}

cache_override_confirmation () {
  file="$1"
  if ! test -e "$file" ; then return 0 ; fi ;

  echo "There's a cached version of the requested data here: $(realpath "$file")"
  echo "I have to override it to continue. Continue?"
  if ask_for_confirmation ;
  then
    echo "overriding..." ;
    rm -f -r "$file"  ;
    return 0 ;
  else
    echo 'You answered "no": nothing done.' ;
    return 1 ;
  fi ;
}

ask_for_confirmation () {
  echo 'Answer "y" for "yes" or "n" for "no", then press enter.'
  if test "$option_f_set" ;
  then
    echo 'option -f set, automatically answered yes.' ;
    return 0 ;
  fi ;
  read answer </dev/tty ;
  echo ;
  case "$answer" in
  'y')  return 0 ;
  ;;
  'n') return 1 ;
  ;;
  *)
    echo 'answer not recognized. Retrying...' ; 
    ask_for_confirmation ;
    return $? ;
  ;;
  esac ;
}

load_reference_databases_translations () {
  query='
    load csv with headers from "file:///load/files/prefixes_translated_by_a_human.csv" as row
    merge (krd:KeggReferenceDatabase{keggPrefix:row.prefix})
    with row,krd
    merge (rd:ReferenceDatabase{displayName:row.`reactome displayName`})
    with row,krd,rd
    merge (krd)-[:keggCrossReference]->(rd)
    return krd.keggPrefix,rd.displayName
    ;
    '
  echo "$query" | $to_cypher_shell_with_login ;
}

download_new_genes () {
  if ! cache_override_confirmation "$genes_list_file_new" ; then return; fi;
  echo "download new genes" >"$journal" ;
  if_exists_remove "$genes_list_file_diff" "$genes_list_file_new" ;
  wget -o "$wget_log" -O "$genes_list_file_new" "$genes_list_link" ;
  echo '' >"$journal" ;
  echo "download complete: $(wc -l <"$genes_list_file_new") genes downloaded."
}

download_new_cross_references () {

  if ! test -e "$genes_list_file_new" ; then echo 'You must download a new gene list before you can cross reference them. Use the "download new genes" command and try again.'; return ; fi ;
  if ! cache_override_confirmation "$cross_references_directory_new" ; then return ; fi;

  echo "download new cross references" >"$journal" ;

  if_exists_remove "$further_cross_references_directory" "$cross_references_directory_new" "$cross_references_directory_diff" ;
  mkdir  "$further_cross_references_directory" "$cross_references_directory_new"  ; #yes, only 2 of them

  echo "LEGEND:" ;
  echo '"percentage completed" "genes downloaded":"genes remaining"="seconds remaining" "current gene downloading command"' ;

  mkfifo "$parallel_fifo" ;

  cat "$genes_list_file_new" | cut -f 1 | while read gene ;
  do echo "wget -o '$wget_log' -O - '$cross_references_link$gene' | while IFS='	' read hsa other link_type ; do echo "'$hsa'"'	'"'$other'"'	'"'[$link_type]$other ; '" done> '$cross_references_directory_new/$gene'" ;
  done >"$parallel_fifo" &

  rm -f "$parallel_fifo"

  parallel --bar --jobs "$number_of_parallel_jobs" <"$parallel_fifo";

  parallel_exit_status="$?"
  rm -f "$parallel_fifo"
  if ! handle_parallel_exit "$parallel_exit_status" ;
  then  return 1 ;
  fi ;

  echo 'Now downloading external cross references dump files. Please wait.'
  mkfifo "$parallel_fifo" ;

  for file_link in "$uniprot_cross_references_link" "$ncbi_gene_to_ensembl" "$ncbi_gene_to_refseq" "$ncbi_refseq_uniprot_collab" "$ensembl_to_ena" "$ensembl_to_entrez" "$ensembl_to_refseq" "$ensembl_to_uniprot"
  do echo "$file_link" ;
  done >"$parallel_fifo" &

#parallel --bar --jobs "$number_of_parallel_jobs" wget --compression=none  -o "$wget_log" -P "$further_cross_references_directory"  <"$parallel_fifo" ;
#sadly, the previous line generates an error: i have to hard code the $number_of_parallel_jobs to 1, lest the subsequent call to "gzip -d *" fails to decompress some files. I suspect (aka stack overflow suggested) that it may be a between gzip and wget, which i haven't really understood...wget fails to handle something... i don't know... i don't want to know... i wasted ... ehm i mean "spent"... 5 hours of my 20s debugging that line, i think i sacrified enough blood on its altar.

parallel --bar --jobs 1 wget --compression=none  -o "$wget_log" -P "$further_cross_references_directory"  <"$parallel_fifo" ;


 parallel_exit_status="$?"
  rm -f "$parallel_fifo"
  if ! handle_parallel_exit "$parallel_exit_status" ;
  then  return 1 ;
  fi ;

  gzip -d "$further_cross_references_directory"/*

  echo '' >"$journal" ; #empty the journal, to tell that the job was completed succesfully
  echo "all downloads completed."
}

count_missing_new_genes () {

  if ! test -e "$genes_list_file_new" ; then echo 'You must download a new list of genes before you can compare it to the current one. Use the "download new genes" command and try again. Nothing done, exiting now...' ; return ; fi ;
  if_exists_remove "$genes_list_file_diff" ;
   tmp="$(mktemp)"
   cat "$genes_list_file" | sort >"$tmp"
   cat "$genes_list_file_new" | sort  | comm -23 - "$tmp" >"$genes_list_file_diff" ;
  rm -f "$tmp"

  echo "$(cat "$genes_list_file_diff" | wc -l)" ;
}

count_missing_new_cross_references () {
  if ! test -e "$cross_references_directory_new" ; then echo 'You must download new cross references before you can compare them to the current aones. Use the "download new cross references" command and try again. Nothing done, exiting now...' ; return ; fi ;

  echo 'count missing new cross references'>"$journal"
  if_exists_remove "$cross_references_directory_diff" ;
  mkdir "$cross_references_directory_diff";

  
   echo "LEGEND:" ;
   echo '"percentage completed" "genes completed":"genes remaining"="seconds remaining" "current gene being cross referenced"' ;
   mkfifo "$parallel_fifo" ;
   ls "$cross_references_directory_new" >"$parallel_fifo" &
   parallel --jobs "$number_of_parallel_jobs"  --bar /bin/sh "cross_references_translate_thread.sh" <"$parallel_fifo" ;
    rm "$parallel_fifo" ;

  ls "$cross_references_directory_new" | while read gene ;
  do
    new_gene_file="$cross_references_directory_new/$gene" ;
    old_gene_file="$cross_references_directory/$gene" ;
    {
      if test -e "$old_gene_file" ;
      then
        tmp="$(mktemp)" ;
        cat "$old_gene_file" | sort >"$tmp" ;
        cat "$new_gene_file" | sort | comm -23 - "$tmp" ;
        rm -f "$tmp" ;
      else cat "$new_gene_file" ;
      fi ;
     } >"$cross_references_directory_diff/$gene" ;

   done ;
   if test "$( ls $cross_references_directory_diff )" ;
   then echo "$( cat "$cross_references_directory_diff"/* | wc -l )"
   else echo 0 ;
   fi  ;
   echo ''>"$journal"
}

load_missing_new_genes () {
if ! test -e "$genes_list_file_diff" ;
then
  echo 'you have to count the missing new genes first, there may be none of them!'  ;
  return 1 ;
fi ;

echo 'load missing new genes' >"$journal"
prepare_neo4j ;

assign_to_threads load_missing_new_genes_thread <"$genes_list_file_diff" ;

assign_to_threads_exit_status="$?"

if test "$assign_to_threads_exit_status" -ne 0 ;
then return 1 ;
fi ;

cat "$genes_list_file_diff" >>"$genes_list_file"
rm -f "$genes_list_file_diff" ;
echo '' >"$journal"
echo 'load complete.'
}

load_missing_new_cross_references () {
   if ! test -e "$cross_references_directory_diff" ;
  then
    echo 'you have to count the missing new cross references first, there may be none of them!'  ;
    return 1 ;
  fi ;
  echo 'load missing new cross references' >"$journal"  ;

  prepare_neo4j ;
  if_exists_remove "$parallel_fifo"
  mkfifo  "$parallel_fifo";

  ls "$cross_references_directory_diff" >"$parallel_fifo" &
  assign_to_threads load_missing_new_cross_references_thread <"$parallel_fifo" ;
  assign_to_threads_exit_status="$?" ;
  rm -f "$parallel_fifo" ;

  if test "$assign_to_threads_exit_status" -ne 0 ;
  then return 1 ;
  fi ;

  ls "$cross_references_directory_diff" | while read file ;
  do cat "$cross_references_directory_diff"/"$file" >>"$cross_references_directory"/"$file"  ;
  done ;


  echo '' >"$journal"
  echo 'load complete.'
}


assign_to_threads () {
  function_to_call="$1"
  if_exists_remove "$splitting_directory"
  mkdir "$splitting_directory" ;
  split -l "$genes_per_batch" - "$splitting_directory"/ ;

  echo "LEGEND:" ;
  echo '"percentage completed" "jobs completed":"jobs remaining"="seconds remaining" "current job command"' ;

  mkfifo "$parallel_fifo" ;
  ls "$splitting_directory" | shuf | while read file ;
  do echo "$splitting_directory"/"$file"  ;
  done >"$parallel_fifo" &
  parallel --bar --joblog "$joblog" --jobs "$number_of_parallel_jobs" /bin/sh "load_thread.sh" "$function_to_call" <"$parallel_fifo" ;
  parallel_exit_status="$?" ;
  rm  -f "$parallel_fifo" ;

  if ! handle_parallel_exit "$parallel_exit_status" ;
  then return 1 ;
  fi ;
}

handle_parallel_exit () {
  parallel_exit_status="$1"
  case "$parallel_exit_status" in
  '0') return 0
  ;;
  '255')  return 1 ;
  ;;
  *)
    retry_failed_jobs ;
    return "$?" ;
  ;;
  esac ;
}

retry_failed_jobs () {
  echo 'Retrying failed jobs...'
  while ! parallel --joblog "$joblog" --retry-failed --bar ;
  do true ;
  done ;
  #while true ;
  #do
  #  echo retrying failed jobs...
  #  jobs_launched_n_old="$(cat joblog | wc -l )" ;
  #  parallel --joblog joblog --retry-failed --bar ;
  #  exit_status=$?
  #  jobs_launched_n_new="$(cat joblog | wc -l )" ;
  #  if test "$jobs_launched_n_old" -eq "$jobs_launched_n_new" ;
  #  then break ;
  #  fi ;
  #  done ;
  #  return $exit_status ; 
}

if_exists_remove(){
  for file in "$@" ; 
  do if test -e "$file" ; then rm -f -r "$file" ; fi ;
  done ;
}

login () {
   shift ; #removes the 'login' from the command
   if ! test $# -eq 2 ;
   then
     echo 'invalid login arguments' ;
     return 1 ;
   fi ;
   x="../../../bin/cypher-shell -u '$1' -p '$2'"
   echo "$x"' "$@"' >".to_cypher.sh" ;
   if ! check_logged_in ;
   then echo 'ERROR: login failed.' ; return 1 ;
   fi ;
   echo 'login successful.'
}

check_logged_in () {
  if test -e ".to_cypher.sh" && eval "sh .to_cypher.sh" <'/dev/null';
  then return ;
  else
    echo 'ERROR: Login credentials absent or invalid. Please login and retry.' ;
    return 1 ;
  fi ;
}

prepare_neo4j () {
  $to_cypher_shell_with_login <'../files/cypher_queries/prepare_neo4j' ;
}

delete_loaded_genes_and_cross_references () {
       cat '../files/cypher_queries/delete_loaded_genes_and_cross_references' | $to_cypher_shell_with_login  ;
       exit_status="$?" ;
       if_exists_remove "$genes_list_file" "$cross_references_directory" ;
       return "$exit_status" ;
}

delete_cache () {
      if_exists_remove "$cache_directory" ;
}

auto () {
if ! check_logged_in ; then  echo 'please login first.' ; fi ;
number_of_parallel_jobs='100%'
for command in "delete_cache" "prepare_neo4j" "download_new_genes" "count_missing_new_genes" "load_missing_new_genes" "download_new_cross_references" "count_missing_new_cross_references" "load_missing_new_cross_references" ;
do
  "$command"
  if ! test "$?" -eq  0 ;
  then
    echo ERROR: "$(echo "$command" | tr '_' ' ')" failed. ;
    return 1 ;
  fi ;
done ;
}


main "$@"


